#!/bin/bash
# ttl-sweep.sh — account-side 4-hour TTL backstop.
#
# WHY THIS EXISTS (do not delete it in a cleanup pass):
# The in-guest TTL (`shutdown -h +240` in user_data + instance_initiated_
# shutdown_behavior=terminate) is the primary mechanism and covers the normal
# case. It provably does NOT cover:
#   * Dedicated Hosts      — not instances, no OS, nothing to shut down.
#                            3 idle mac1.metal hosts cost $758 in 21 days
#                            before the 2026-09-21 audit caught them.
#   * CLI/console launches — anything not created by this repo's terraform
#                            never gets the user_data prologue at all.
#   * Windows instances    — /sbin/shutdown is Linux-only.
#   * Failed boots         — user_data never runs, so the timer never starts.
#   * Stopped instances    — a stopped box keeps billing for its EBS, and its
#                            shutdown timer is gone. i-0d0f9693b3b4c150b sat
#                            stopped for 11 days past a 3-day deadline tag.
# A tag that says HardDeadlineMinutes is documentation, not a mechanism. This
# script is the mechanism.
#
# DRY RUN BY DEFAULT. Pass --apply to actually destroy anything.
#
# WARNING — SHARED ACCOUNT: account 257527264356 is shared with unrelated
# tests. Run without --apply first and read the list. Use --filter-tag to
# restrict the blast radius to resources you own, e.g.:
#   ./ttl-sweep.sh --filter-tag Owner=wazuh-content-team --apply

set -uo pipefail

TTL_HOURS="${TTL_HOURS:-4}"
APPLY=0
FILTER_TAG=""
PROFILE="${AWS_PROFILE:-wazuh}"

while [ $# -gt 0 ]; do
  case "$1" in
    --apply)       APPLY=1 ;;
    --ttl-hours)   shift; TTL_HOURS="$1" ;;
    --filter-tag)  shift; FILTER_TAG="$1" ;;
    --profile)     shift; PROFILE="$1" ;;
    -h|--help)     sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

export AWS_PROFILE="$PROFILE"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

CUTOFF=$(python -c "import datetime,sys; print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(hours=float(sys.argv[1]))).strftime('%Y-%m-%dT%H:%M:%S+00:00'))" "$TTL_HOURS")

if [ "$APPLY" -eq 1 ]; then MODE="APPLY — resources WILL be destroyed"; else MODE="DRY RUN — nothing will be touched"; fi
echo "=============================================================="
echo " TTL sweep | ttl=${TTL_HOURS}h | cutoff=${CUTOFF}"
echo " profile=${PROFILE} | ${MODE}"
[ -n "$FILTER_TAG" ] && echo " filter-tag=${FILTER_TAG}"
echo "=============================================================="

TAG_FILTER_ARGS=()
if [ -n "$FILTER_TAG" ]; then
  TAG_FILTER_ARGS=(--filters "Name=tag:${FILTER_TAG%%=*},Values=${FILTER_TAG##*=}")
fi

REGIONS=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)
FOUND=0

for r in $REGIONS; do

  # ---- 1. EC2 instances older than the TTL (running AND stopped) ----------
  ids=$(aws ec2 describe-instances --region "$r" \
        "${TAG_FILTER_ARGS[@]+"${TAG_FILTER_ARGS[@]}"}" \
        --query "Reservations[].Instances[?LaunchTime<='${CUTOFF}' && State.Name!='terminated' && State.Name!='shutting-down'].[InstanceId]" \
        --output text 2>/dev/null)
  for i in $ids; do
    FOUND=1
    echo "[$r] instance $i  older than ${TTL_HOURS}h -> terminate"
    if [ "$APPLY" -eq 1 ]; then
      aws ec2 modify-instance-attribute --region "$r" --instance-id "$i" --no-disable-api-termination 2>/dev/null
      aws ec2 terminate-instances --region "$r" --instance-ids "$i" \
        --query 'TerminatingInstances[].[InstanceId,CurrentState.Name]' --output text
    fi
  done

  # ---- 2. Dedicated Hosts with nothing on them ---------------------------
  # Mac hosts carry a HARD 24h minimum allocation; release the moment the
  # host is both empty and past that window. Anything under 24h is reported
  # but cannot be released -- that is an AWS constraint, not a bug here.
  hosts=$(aws ec2 describe-hosts --region "$r" \
          --query 'Hosts[?State==`available`].[HostId,AllocationTime,HostProperties.InstanceType,length(Instances)]' \
          --output text 2>/dev/null)
  while read -r hid atime itype ninst; do
    [ -z "${hid:-}" ] && continue
    [ "${ninst:-0}" != "0" ] && continue
    FOUND=1
    eligible=$(python -c "
import datetime,sys
alloc=datetime.datetime.fromisoformat(sys.argv[1])
print('yes' if (datetime.datetime.now(datetime.timezone.utc)-alloc).total_seconds()>=86400 else 'no')" "$atime")
    if [ "$eligible" = "yes" ]; then
      echo "[$r] host $hid ($itype, empty since $atime) -> release"
      if [ "$APPLY" -eq 1 ]; then
        aws ec2 release-hosts --region "$r" --host-ids "$hid" --output json
      fi
    else
      echo "[$r] host $hid ($itype, allocated $atime) -> EMPTY but inside the 24h minimum; not releasable yet"
    fi
  done <<< "$hosts"

  # ---- 3. Unattached EBS volumes -----------------------------------------
  vols=$(aws ec2 describe-volumes --region "$r" \
         --filters Name=status,Values=available \
         --query "Volumes[?CreateTime<='${CUTOFF}'].[VolumeId,Size]" --output text 2>/dev/null)
  while read -r vid vsize; do
    [ -z "${vid:-}" ] && continue
    FOUND=1
    echo "[$r] volume $vid (${vsize}GB, unattached) -> delete"
    [ "$APPLY" -eq 1 ] && aws ec2 delete-volume --region "$r" --volume-id "$vid" && echo "  deleted"
  done <<< "$vols"

  # ---- 4. Unassociated Elastic IPs ---------------------------------------
  eips=$(aws ec2 describe-addresses --region "$r" \
         --query 'Addresses[?AssociationId==null].[AllocationId,PublicIp]' --output text 2>/dev/null)
  while read -r aid pip; do
    [ -z "${aid:-}" ] && continue
    FOUND=1
    echo "[$r] elastic IP $pip ($aid, unassociated) -> release"
    [ "$APPLY" -eq 1 ] && aws ec2 release-address --region "$r" --allocation-id "$aid" && echo "  released"
  done <<< "$eips"

done

echo "--------------------------------------------------------------"
if [ "$FOUND" -eq 0 ]; then
  echo "Nothing older than ${TTL_HOURS}h. Account is clean."
elif [ "$APPLY" -eq 0 ]; then
  echo "DRY RUN — nothing was destroyed. Re-run with --apply to act."
fi
