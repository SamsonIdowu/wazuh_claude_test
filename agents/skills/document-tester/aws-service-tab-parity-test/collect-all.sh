#!/bin/bash
# awsrc1 collection harness. Runs every "Monitoring AWS" service through the Wazuh module for AWS
# exactly as the doc's snippet configures it, on whichever host it is run (4.14 manager or the 5.0
# RC1 agent). Output per run goes to /root/rc1/out/<label>.log.
#
#   Usage: [ONLY_LOGS_AFTER=2026-OCT-01] collect-all.sh <label-regex>
#          e.g. collect-all.sh .   (all)   collect-all.sh 'waf|alb'
set -uo pipefail
M=wazuh-rc1-logs-257527264356
W=/var/ossec/wodles/aws/aws-s3
D=${ONLY_LOGS_AFTER:-$(date -u +%Y-%b-%d | tr '[:lower:]' '[:upper:]')}
OUT=/root/rc1/out; mkdir -p "$OUT"
SEL="${1:-.}"

run() {
  local label="$1"; shift
  [[ "$label" =~ $SEL ]] || return 0
  {
    echo "### $label  $(date -u +%FT%TZ)  host=$(hostname)"
    echo "CMD: aws-s3 $*"
    timeout 600 "$W" "$@" -d 2 2>&1 | grep -vE '^DEBUG: \{|Reformat message' | tail -40
    echo "EXIT=${PIPESTATUS[0]}"
  } > "$OUT/$label.log" 2>&1
  printf '%-28s %s\n' "$label" "$(grep -m1 '^EXIT=' "$OUT/$label.log")"
}

# Bucket-backed services: the doc's snippet values, with --only_logs_after so a rerun replays.
run cloudtrail          -b $M -t cloudtrail -p default --only_logs_after $D --reparse
run cloudtrail-logins   -b $M -t cloudtrail -l consolelogin-replay -p default --only_logs_after 2026-JUL-01 --reparse
run vpc                 -b $M -t vpcflow -p default --only_logs_after $D --reparse
run config              -b $M -t config -l config -p default --only_logs_after $D --reparse
run kms                 -b $M -t custom -l kms_compress_encrypted -p default --only_logs_after $D --reparse
run macie               -b $M -t custom -l macie -p default --only_logs_after $D --reparse
run guardduty-verbatim  -b $M -t guardduty -p default --only_logs_after $D --reparse
run guardduty           -b $M -t guardduty -l guardduty -p default --only_logs_after $D --reparse
run waf                 -b $M -t waf -l waf -p default --only_logs_after $D --reparse
run s3-server-access    -b $M -t server_access -l s3-server-logs -p default --only_logs_after $D --reparse
run alb                 -b $M -t alb -l ALB -p default --only_logs_after $D --reparse
run clb                 -b $M -t clb -l CLB -p default --only_logs_after $D --reparse
run nlb                 -b $M -t nlb -l NLB -p default --only_logs_after $D --reparse
run umbrella-dns        -b $M -t cisco_umbrella -l dnslogs -p default --only_logs_after $D --reparse
run umbrella-proxy      -b $M -t cisco_umbrella -l proxylogs -p default --only_logs_after $D --reparse

# Service-backed.
run inspector           -sr inspector -r us-east-1,us-east-2 -p default --only_logs_after $D
run cloudwatch-logs     -sr cloudwatchlogs -g wazuh-rc1-loggroup -r us-east-1 -p default --only_logs_after $D
run ecr-verbatim        -sr cloudwatchlogs -g /aws/ecr/wazuh-rc1-repo -p default --only_logs_after $D
run ecr                 -sr cloudwatchlogs -g /aws/ecr/image-scan-findings/wazuh-rc1-repo -r us-east-1 -p default --only_logs_after $D

# SQS subscribers. These DELETE what they read, so run one host at a time and re-notify in between.
run security-hub        -sb security_hub -q wazuh-rc1-sechub -p default
run security-lake       -sb security_lake -q wazuh-rc1-seclake -p default -i arn:aws:iam::257527264356:role/wazuh-rc1-seclake-role -x WAZUH-EXTERNAL-ID-VALUE -rd 1300
run custom-buckets      -sb buckets -q wazuh-rc1-custom -p default
echo DONE
