#!/usr/bin/env python3
"""awsrc1 4.x evidence: classify every AWS-module event in archives.json/alerts.json by service,
write per-service samples and a rule tally.   Usage: v4-evidence.py <outdir>"""
import json, sys, os, collections

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)


def service(aws):
    lf = (aws.get('log_info') or {}).get('log_file', '') or ''
    src = aws.get('source', '') or ''
    for pfx, name in (('consolelogin-replay/', 'cloudtrail-logins'), ('kms_compress_encrypted/', 'kms'),
                      ('macie/', 'macie'), ('guardduty/', 'guardduty'), ('waf/', 'waf'),
                      ('s3-server-logs/', 's3-server-access'), ('ALB/', 'alb'), ('CLB/', 'clb'),
                      ('NLB/', 'nlb'), ('config/', 'config'), ('dnslogs/', 'umbrella-dns'),
                      ('proxylogs/', 'umbrella-proxy'), ('app/2026', 'custom-buckets')):
        if lf.startswith(pfx):
            return name
    if 'vpcflowlogs' in lf:
        return 'vpc'
    if '/CloudTrail/' in lf:
        return 'cloudtrail'
    if 'CLOUD_TRAIL_MGMT' in lf or src == 'security_lake':
        return 'security-lake'
    if src in ('inspector', 'inspector2'):
        return 'inspector'
    if src == 'securityhub' or 'securityhub' in json.dumps(aws)[:400].lower():
        return 'security-hub'
    if src == 'cloudwatchlogs':
        lg = aws.get('log_group', '') or ''
        return 'ecr' if 'image-scan-findings' in lg else 'cloudwatch-logs'
    if src == 'custom' or 'wazuh-rc1-custom' in lf:
        return 'custom-buckets'
    return 'other:' + (src or lf[:30])


def classify_event(e):
    """Service of an archived event or alert, or None if it did not come from the AWS module.
    CloudWatch Logs, ECR (via CloudWatch) and Security Lake events carry no data.aws on 4.x:
    the module forwards the raw message, which the stock json/sshd/sudo decoders then parse."""
    aws = (e.get('data') or {}).get('aws')
    if aws is not None:
        return service(aws)
    if e.get('location') != 'Wazuh-AWS':
        return None
    fl = e.get('full_log', '') or ''
    if '"class_uid"' in fl:
        return 'security-lake'
    if fl.startswith('{"name": "CVE-') or '"UNDEFINED":' in fl or 'imageScanFindings' in fl:
        return 'ecr'
    return 'cloudwatch-logs'


def load(path):
    with open(path, errors='replace') as f:
        for line in f:
            try:
                yield json.loads(line)
            except ValueError:
                continue


archives = collections.defaultdict(list)
for e in load('/var/ossec/logs/archives/archives.json'):
    s = classify_event(e)
    if s:
        archives[s].append(e)

alerts = collections.defaultdict(list)
tally = collections.Counter()
for a in load('/var/ossec/logs/alerts/alerts.json'):
    s = classify_event(a)
    if not s:
        continue
    alerts[s].append(a)
    r = a.get('rule', {})
    tally[(s, r.get('id'), r.get('level'), r.get('description', '')[:90])] += 1

summary = {}
for s in sorted(set(archives) | set(alerts)):
    d = os.path.join(OUT, s.replace(':', '_').replace('/', '_'))
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, '4x-archives-sample.jsonl'), 'w') as f:
        for e in archives[s][:5]:
            f.write(json.dumps(e) + '\n')
    seen = set()
    with open(os.path.join(d, '4x-alerts-sample.jsonl'), 'w') as f:
        for a in alerts[s]:
            rid = a['rule']['id']
            if rid in seen:
                continue
            seen.add(rid)
            f.write(json.dumps(a) + '\n')
    summary[s] = {'archived_events': len(archives[s]), 'alerts': len(alerts[s]),
                  'rules': sorted({a['rule']['id'] for a in alerts[s]})}

with open(os.path.join(OUT, '4x-rule-tally.txt'), 'w') as f:
    for k, n in sorted(tally.items(), key=lambda x: (x[0][0], str(x[0][1]))):
        f.write(f"{k[0]:18s} rule={k[1]:6s} level={k[2]:<3} x{n:<5} {k[3]}\n")
json.dump(summary, open(os.path.join(OUT, '4x-summary.json'), 'w'), indent=1)
for s, v in summary.items():
    print(f"{s:20s} archived={v['archived_events']:6d} alerts={v['alerts']:6d} rules={','.join(v['rules'])}")
