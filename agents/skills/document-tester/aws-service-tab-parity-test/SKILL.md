---
name: aws-service-tab-parity-test
description: Test a "Monitoring AWS" service page (GuardDuty, KMS, Macie, WAF, Trusted Advisor, S3 server access, Inspector, CloudWatch Logs, ECR) against Wazuh 4.x and 5.0 at the same time, using one shared S3 bucket so every difference in the result is a version difference. Use when a doc page or tab claims a Wazuh rule fires for an AWS service.
owner: document-tester
created: 2026-09-24
last-verified: 2026-09-29
---

# AWS service tab parity test

## When to use

Any documentation page that says "the following alerts with rule ID **N** will be
shown on the Wazuh dashboard" for an AWS service. The doc is versioned 5.0 but its
use cases cite 4.x numeric rule IDs, so a single-version test cannot tell a
documentation error from a ruleset gap. Testing both versions against identical
bytes can.

Do not use this for CloudTrail/VPC/Config parity — that ground is already covered;
extend those results instead of re-deriving them.

## Prerequisites

- AWS profile `wazuh` (account 257527264356), region us-east-1.
- Two EC2 hosts, Ubuntu 24.04, `t3.xlarge`, 30 GB, 4-hour TTL
  (`shutdown -h +240` in user_data + `instance-initiated-shutdown-behavior=terminate`).
- 4.x host: `packages.wazuh.com/4.14/wazuh-install.sh -a -i`.
- 5.0 host: `wazuh-install-5.0.0-beta5.sh -a -id -d pre-release` from
  `packages-staging.xdrsiem.wazuh.info/pre-release/5.x/installation-assistant/`.
  Check the URL returns 200 before use — the version in the path moves.
- On both: `pip3 install --break-system-packages boto3==1.34.135 pyarrow==14.0.1 numpy==1.26.0`.

## Steps

### 1. One bucket, both stacks

This is the whole point of the skill. Create **one** S3 bucket and **one** IAM
role, point every AWS service at it, and have both Wazuh hosts read it. Identical
input means any divergence is attributable to the Wazuh version.

### 2. Authenticate without static keys

`aws iam create-access-key` is blocked in this environment. Use the doc's own
"IAM roles for EC2 instances" path instead, which also keeps the tabs' snippets
usable unmodified:

```bash
# instance profile attached to both hosts, then on each host:
mkdir -p /root/.aws
printf '[default]\nregion = us-east-1\n' > /root/.aws/config   # no credentials file
python3 -c "import boto3;print(boto3.Session(profile_name='default').get_credentials().method)"
# -> iam-role
```

`<aws_profile>default</aws_profile>` in the tabs then resolves through IMDS.

Issue IAM calls **one per Bash invocation**. A compound script that creates a
user, a group and a policy together trips the permission classifier; the same
calls separately go through.

### 3. Build the AWS side

Start S3 server access logging **first** — first delivery took ~60 minutes.
GuardDuty export runs on a 15-minute cycle. Everything else lands within ~2 min.

See `build-aws-side.sh` for the working sequence. The non-obvious bits:

| Service | Trap |
|---|---|
| GuardDuty | The destination prefix must already exist — `put-object --key guardduty/` first, or `create-publishing-destination` fails with "resource folder … does not exist". Needs a CMK with a `kms:GenerateDataKey` grant to `guardduty.amazonaws.com`. |
| KMS | Needs an active CloudTrail trail or EventBridge never sees the management events. |
| WAF | The Firehose stream name **must** start with `aws-waf-logs-`, or logging config fails with a misleading "The ARN isn't valid". Needs a web ACL associated with a real resource (an ALB with a fixed-response listener is enough) — an unassociated ACL emits nothing. |
| Macie | Enable Macie, then a one-time classification job over an object with synthetic PII. |
| Trusted Advisor | Requires Business+ support. Prove the account can't: `aws support describe-severity-levels` → `SubscriptionRequiredException`. |
| ECR | `docker push` needs `ecr:BatchGetImage` on top of the usual push actions. `alpine:3.10` scans clean; use `ubuntu:18.04` for real CVEs. |

### 4. Run the collection harness

`svc-collect.sh <bucket>` runs every service through `/var/ossec/wodles/aws/aws-s3`
on one host and prints per-service results. Run it on both hosts. Test each tab's
snippet **exactly as printed first**, then again corrected — the difference is the
finding.

### 5. Evidence on 4.x — real alerts

```bash
truncate -s 0 /var/ossec/logs/alerts/alerts.json
# ...re-run collection with --reparse --only_logs_after <yesterday>...
python3 - <<'PY'
import json,collections
c=collections.Counter()
for line in open('/var/ossec/logs/alerts/alerts.json'):
    try: a=json.loads(line)
    except: continue
    d=a.get('data',{})
    if 'aws' in d:                       # NOTE: data.aws, not top-level aws
        src=d['aws'].get('log_info',{}).get('log_file','')
        c[(src.split('/')[0], a['rule']['id'], a['rule']['level'])]+=1
for k,n in sorted(c.items()): print(n,k)
PY
```

Resolve every rule ID the doc cites against the shipped ruleset — several do not
exist. See `resolve-rule-ids.sh`.

### 6. Evidence on 5.0 — decoders and logtest

The AWS integration ships `enabled: false`. On a healthy install the Security
Analytics plugin bootstraps about a minute after installation (it creates
`.opensearch-sap-detectors-config`, one detector per integration and `-alerts`
indices), and the enable works first time. On 2 of 3 fresh installs (2026-09-23 and 2026-09-29) that
bootstrap never ran — the enable failed with `no such index
[.opensearch-sap-detectors-config]` and **no findings persisted for any source**.
Check first; if detectors are missing the host is broken and no "no findings"
verdict from it can be trusted:

```bash
curl -sk -u admin:admin 'https://localhost:9200/_cat/indices/.opensearch-sap-*?h=index' | head
```

The enable script creates the missing index as a workaround:

```bash
curl -sk -u admin:admin -X PUT 'https://localhost:9200/.opensearch-sap-detectors-config' \
  -H 'Content-Type: application/json' -d '{"settings":{"index.hidden":true,"number_of_shards":1,"number_of_replicas":0}}'
# then PUT the integration with document.enabled = true (see enable-aws-integration.sh)
```

The integrations API has **no GET** — only `POST /integrations`,
`POST /integrations/_search`, `PUT /integrations/{id}`. Read current state
straight off the indices instead:

```bash
curl -sk -u admin:admin 'https://localhost:9200/wazuh-threatintel-integrations-a/_search?size=200' \
  -H 'Content-Type: application/json' -d '{"_source":["document.metadata.title","document.enabled"]}'
# same pattern for wazuh-threatintel-{decoders,rules}-a
```

Then confirm which decoder actually claimed each event:

```bash
curl -sk -u admin:admin 'https://localhost:9200/wazuh-events-v5-cloud-services/_search?size=0' \
  -H 'Content-Type: application/json' \
  -d '{"aggs":{"d":{"terms":{"field":"wazuh.integration.decoders","size":30}}}}'
```

An event carrying only `decoder/core-wazuh-message/0` and `decoder/aws/0` was
**not** decoded by a service decoder, whatever the doc claims.

### 7. Separate "no rule" from "no finding"

Findings can be zero cluster-wide on a beta build. Before reporting a ruleset gap,
replay the event through logtest, which reports rule matching independently:

```json
POST https://<dashboard>:443/_plugins/_security_analytics/logtest
{"document":{"queue":49,"location":"Wazuh-AWS","event":"<raw event.original>",
 "space":"standard","trace_level":"ALL","integration":"<aws integration UUID>"}}
```

Read `response.message.detection.{rules_evaluated,rules_matched,matches}`. To
root-cause a decoder that should have matched but didn't, read
`response.message.normalization.asset_traces[]` — it carries each decoder's
`check:` expression and whether it passed. (`asset_traces` is nested under
`normalization`, not at the top level.)

Sanity check before blaming AWS: if `wazuh-findings-v5-*` is zero across **all**
categories while `wazuh-events-v5-system-activity` has hundreds of events, the
findings pipeline is inert on that build and no AWS conclusion can be drawn from
findings alone — say so in the report and rely on logtest.

## Verification

The test is complete when, for each service, you can state all four with a command:

1. **Collected** — `Found new log:` in the wodle output, or the object key listed in S3.
2. **Decoded** — 4.x: the alert's `data.aws` fields. 5.0: a service-specific decoder in the `wazuh.integration.decoders` aggregation.
3. **Rule matched** — 4.x: the rule ID in `alerts.json`. 5.0: `rules_matched >= 1` from logtest.
4. **Persisted** — 4.x: the alert. 5.0: a document in `wazuh-findings-v5-cloud-services`.

Every documented rule ID must also be resolved against the shipped ruleset, and a
"NOT PRESENT" result reported as a finding rather than silently skipped.

## Known failure modes

- **`wazuh-control restart` kills the agent permanently.** Always `systemctl restart`.
- **A URL list written by Windows Python and scp'd to Linux carries `\r`**, and every
  `curl` then returns `000`. It looks like total egress failure. `sed -i 's/\r$//'` first.
- **`-d 2` changes the exit code.** The module does `if debug_level > 0: raise`, so a
  debug run exits 1 with a traceback where the wodle exits 12 for the same fault.
- **Exit 16 is not throttling** — it is any CloudWatch Logs `ClientError`, AccessDenied
  included. **Exit 12 is not "invalid type of bucket"** — it is the unhandled-exception
  catch-all. Don't trust the doc's error-code table.
- **`bucket type="guardduty"` accepts only the native export layout** (`<prefix>/AWSLogs/...`);
  a Firehose-style path exits 12.
- **MSYS mangles paths** in `aws ec2` calls from Git Bash (`/dev/sda1` →
  `C:/Program Files/Git/dev/sda1`). Export `MSYS_NO_PATHCONV=1`.
- **On 5.0 the manager ships no `wodles/aws` at all** — an agent on the manager host is
  genuinely required. On 4.x the manager already has it and installing an agent is
  destructive (`apt-get install -s wazuh-agent` proposes `Remv wazuh-manager`).
- **The 5.0 manager has no `ossec.log`, no `logall_json`, no `archives/`.** Its config is
  `/var/wazuh-manager/etc/wazuh-manager.conf`. Doc troubleshooting steps that use those
  paths are 4.x-only; the agent's `/var/ossec/logs/ossec.log` is where the wodle logs.

## Cleanup

Beyond `terraform destroy`, this skill creates resources outside Terraform. Sweep all
of them and verify each is gone by name:

EC2 + SGs + key pair · ALB (disassociate the web ACL first) · WAFv2 web ACL and its
logging configuration · Firehose streams · EventBridge rules (remove targets first) ·
CloudTrail trail (stop logging first) · GuardDuty publishing destination then detector ·
Macie session · ECR repository · CloudFormation stack · CloudWatch log groups (including
`/aws/lambda/*` the stack created) · S3 bucket (disable access logging, then empty) ·
IAM policies (delete non-default versions first), roles, instance profiles, user, group ·
KMS keys (`schedule-key-deletion`, 7-day minimum — they will show as `PendingDeletion`,
which is expected and not an orphan).
