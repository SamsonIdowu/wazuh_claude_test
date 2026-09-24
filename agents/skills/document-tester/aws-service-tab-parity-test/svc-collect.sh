#!/bin/bash
# Per-service collection harness for the "Monitoring AWS" service tabs.
# Runs every documented wodle configuration through the AWS module on this host
# and prints what each one actually did. Run on BOTH the 4.x and the 5.0 host.
#
#   Usage: svc-collect.sh <bucket> [repo-name] [log-group] [wodle-dir]
#
# Each tab is run TWICE where the tab's own snippet is suspect: once exactly as
# printed, once corrected. The difference between the two is the finding.

set -uo pipefail

B="${1:?usage: svc-collect.sh <bucket> [repo] [log-group] [wodle-dir]}"
REPO="${2:-wazuh-awstabs-repo}"
LG="${3:-wazuh-awstabs-loggroup}"
W="${4:-/var/ossec/wodles/aws}"
SINCE="$(date -u -d 'yesterday' +%Y-%b-%d)"

run() {
  local label="$1"; shift
  echo
  echo "================ $label ================"
  echo "CMD: $W/aws-s3 $*"
  timeout 240 "$W/aws-s3" "$@" 2>&1 | tail -25
  echo "EXIT=${PIPESTATUS[0]}"
}

echo "host=$(hostname)  bucket=$B  only_logs_after=$SINCE"
"$W/aws-s3" --help >/dev/null 2>&1 || { echo "FATAL: no AWS module at $W"; exit 1; }

# --- GuardDuty: the tab's snippet has no <path>, which silently collects nothing
run "GuardDuty — tab snippet verbatim (no path)" \
    -b "$B" -t guardduty -p default -d 2
run "GuardDuty — corrected (path=guardduty)" \
    -b "$B" -t guardduty -l guardduty -p default -d 2

# --- bucket-backed services
run "KMS (custom, path=kms_compress_encrypted)" \
    -b "$B" -t custom -l kms_compress_encrypted -p default -d 2
run "Macie (custom, path=macie)" \
    -b "$B" -t custom -l macie -p default -d 2
run "Trusted Advisor (custom, path=trusted-advisor)" \
    -b "$B" -t custom -l trusted-advisor -p default -d 2
run "WAF (waf, path=waf)" \
    -b "$B" -t waf -l waf -p default -d 2
run "S3 server access (server_access, path=s3-server-logs)" \
    -b "$B" -t server_access -l s3-server-logs -p default -d 2

# --- service-backed
run "CloudWatch Logs" \
    -sr cloudwatchlogs -g "$LG" -r us-east-1 -p default -d 2

# --- ECR: the tab's log group does not exist; the template creates the other one
run "ECR — tab's log group /aws/ecr/<repo>" \
    -sr cloudwatchlogs -g "/aws/ecr/$REPO" -r us-east-1 -p default -d 2
run "ECR — template's real log group /aws/ecr/image-scan-findings/<repo>" \
    -sr cloudwatchlogs -g "/aws/ecr/image-scan-findings/$REPO" -r us-east-1 -p default -d 2

# --- Inspector: the module calls inspector2, not Inspector Classic
run "Inspector (service inspector -> calls inspector2)" \
    -sr inspector -r us-east-1 -p default -d 2

echo
echo "ALL_SERVICE_TESTS_DONE"
echo "Reminder: re-run with --reparse --only_logs_after $SINCE to replay already-processed objects."
