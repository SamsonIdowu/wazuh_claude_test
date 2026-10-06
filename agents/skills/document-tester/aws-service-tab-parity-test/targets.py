#!/usr/bin/env python3
"""awsrc1 gap samples. For each target event, pull the SAME raw record from this host's store:
  v4: archives.json entry + every alert raised on it
  v5: wazuh-events-v5-* doc + every finding on it + logtest under each AWS integration
Both hosts read identical bytes from the shared bucket, so the raw record is the join key.
Usage: targets.py v4|v5 <outdir>"""
import json, sys, os, subprocess

MODE, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)


def J(raw):
    try:
        j = json.loads(raw)
        return j.get('aws', j) if isinstance(j, dict) else {}
    except (ValueError, TypeError):
        return {}


def has(raw, *subs):
    return all(s in raw for s in subs)


def ct(name, denied):
    def p(raw, a):
        err = str(a.get('errorCode') or '')
        ok = ('Unauthorized' in err or 'AccessDenied' in err) if denied else not err
        return a.get('eventName') == name and ok and '/CloudTrail/' in raw
    return p


# id, service, what it shows, predicate(raw, aws_dict)
TARGETS = [
    ('ct-denied-runinstances', 'cloudtrail', 'RunInstances denied (UnauthorizedOperation)', ct('RunInstances', True)),
    ('ct-denied-startinstances', 'cloudtrail', 'StartInstances denied', ct('StartInstances', True)),
    ('ct-denied-stopinstances', 'cloudtrail', 'StopInstances denied', ct('StopInstances', True)),
    ('ct-denied-createsecuritygroup', 'cloudtrail', 'CreateSecurityGroup denied', ct('CreateSecurityGroup', True)),
    ('ct-denied-allocateaddress', 'cloudtrail', 'AllocateAddress denied', ct('AllocateAddress', True)),
    ('ct-denied-createuser', 'cloudtrail', 'IAM CreateUser denied (AccessDenied)', ct('CreateUser', True)),
    ('ct-success-runinstances', 'cloudtrail', 'RunInstances succeeded', ct('RunInstances', False)),
    ('ct-success-createsecuritygroup', 'cloudtrail', 'CreateSecurityGroup succeeded', ct('CreateSecurityGroup', False)),
    ('ct-success-authorizesgingress', 'cloudtrail', 'AuthorizeSecurityGroupIngress succeeded', ct('AuthorizeSecurityGroupIngress', False)),
    ('ct-success-createrole', 'cloudtrail', 'IAM CreateRole succeeded', ct('CreateRole', False)),
    ('login-failure', 'cloudtrail-logins', 'ConsoleLogin failure (real record, redacted)',
     lambda r, a: a.get('eventName') == 'ConsoleLogin' and (a.get('responseElements') or {}).get('ConsoleLogin') == 'Failure'),
    ('login-success-mfa', 'cloudtrail-logins', 'ConsoleLogin success with MFA',
     lambda r, a: a.get('eventName') == 'ConsoleLogin' and (a.get('responseElements') or {}).get('ConsoleLogin') == 'Success'
     and (a.get('additionalEventData') or {}).get('MFAUsed') == 'Yes'),
    ('login-success-nomfa', 'cloudtrail-logins', 'ConsoleLogin success without MFA',
     lambda r, a: a.get('eventName') == 'ConsoleLogin' and (a.get('responseElements') or {}).get('ConsoleLogin') == 'Success'
     and (a.get('additionalEventData') or {}).get('MFAUsed') == 'No'),
    ('kms-createkey', 'kms', 'KMS CreateKey via EventBridge/Firehose', lambda r, a: has(r, 'kms_compress_encrypted/') and has(r, 'CreateKey')),
    ('kms-schedulekeydeletion', 'kms', 'KMS ScheduleKeyDeletion', lambda r, a: has(r, 'kms_compress_encrypted/', 'ScheduleKeyDeletion')),
    ('vpc-reject', 'vpc', 'VPC flow record REJECT', lambda r, a: 'vpcflowlogs' in r and a.get('action') == 'REJECT'),
    ('vpc-accept', 'vpc', 'VPC flow record ACCEPT', lambda r, a: 'vpcflowlogs' in r and a.get('action') == 'ACCEPT'),
    ('config-item', 'config', 'AWS Config configuration item', lambda r, a: has(r, '"log_file": "config/') and 'configurationItemStatus' in a),
    ('macie-finding', 'macie', 'Macie sensitive-data finding', lambda r, a: has(r, '"log_file": "macie/') and 'SensitiveData' in r),
    ('macie-policy-finding', 'macie', 'Macie policy finding', lambda r, a: has(r, '"log_file": "macie/') and 'Policy:IAMUser' in r),
    ('guardduty-finding', 'guardduty', 'GuardDuty finding (sample)', lambda r, a: has(r, '"log_file": "guardduty/') and 'UnauthorizedAccess' in r),
    ('waf-block-admin', 'waf', 'WAF BLOCK by custom rule (/admin)', lambda r, a: has(r, '"log_file": "waf/') and a.get('action') == 'BLOCK' and 'block-admin-path' in r),
    ('waf-block-sqli', 'waf', 'WAF BLOCK by AWS SQLi managed rule', lambda r, a: has(r, '"log_file": "waf/') and a.get('action') == 'BLOCK' and 'SQLi' in r),
    ('alb-403', 'alb', 'ALB 403', lambda r, a: has(r, '"log_file": "ALB/') and str(a.get('elb_status_code')) == '403'),
    ('alb-503', 'alb', 'ALB 503', lambda r, a: has(r, '"log_file": "ALB/') and str(a.get('elb_status_code')) == '503'),
    ('clb-503', 'clb', 'CLB 503 (no backends)', lambda r, a: has(r, '"log_file": "CLB/') and str(a.get('elb_status_code')) == '503'),
    ('nlb-tls', 'nlb', 'NLB TLS connection', lambda r, a: has(r, '"log_file": "NLB/')),
    ('s3-access-get', 's3-server-access', 'S3 server access GET', lambda r, a: has(r, 's3-server-logs/') and 'GET' in r),
    ('s3-access-denied', 's3-server-access', 'S3 server access AccessDenied', lambda r, a: has(r, 's3-server-logs/', 'AccessDenied')),
    ('inspector-critical', 'inspector', 'Inspector v2 CRITICAL finding', lambda r, a: a.get('source') == 'inspector2' and a.get('severity') == 'CRITICAL'),
    ('inspector-high', 'inspector', 'Inspector v2 HIGH finding', lambda r, a: a.get('source') == 'inspector2' and a.get('severity') == 'HIGH'),
    ('cw-ssh-failed', 'cloudwatch-logs', 'CloudWatch log: sshd failed password', lambda r, a: 'Failed password for invalid user' in r and 'app-host-1' in r),
    ('cw-sudo', 'cloudwatch-logs', 'CloudWatch log: sudo cat /etc/shadow', lambda r, a: 'COMMAND=/bin/cat /etc/shadow' in r and 'app-host-1' in r),
    ('ecr-critical', 'ecr', 'ECR scan finding CRITICAL (via CloudWatch Logs)', lambda r, a: r.startswith('{"name": "CVE-') and '"severity": "CRITICAL"' in r),
    ('ecr-summary', 'ecr', 'ECR scan summary (severity counts)', lambda r, a: '"UNDEFINED":' in r and '"CRITICAL":' in r and not r.startswith('{"integration"')),
    ('sechub-control-failed', 'security-hub', 'Security Hub control finding FAILED',
     lambda r, a: 'Security Hub Findings - Imported' in r and '"Status": "FAILED"' in r and 'awsrc1-finding' not in r),
    ('sechub-imported', 'security-hub', 'Security Hub imported finding (CRITICAL)',
     lambda r, a: 'Security Hub Findings - Imported' in r and 'awsrc1-finding-1' in r),
    ('sechub-inspector', 'security-hub', 'Security Hub finding forwarded from Inspector', lambda r, a: 'Security Hub Findings - Imported' in r and 'Inspector' in r and 'CVE-' in r),
    ('seclake-failure-ocsf10', 'security-lake', 'Security Lake OCSF 1.0 failed API call', lambda r, a: '"class_uid": 3005' in r and '"status": "Failure"' in r),
    ('seclake-failure-ocsf11', 'security-lake', 'Security Lake OCSF 1.1 failed API call', lambda r, a: '"class_uid": 6003' in r and '"status": "Failure"' in r),
    ('seclake-createuser-ocsf11', 'security-lake', 'Security Lake OCSF 1.1 successful CreateUser', lambda r, a: '"class_uid": 6003' in r and 'CreateUser' in r),
    ('umbrella-dns', 'umbrella-dns', 'Cisco Umbrella DNS log line', lambda r, a: has(r, 'dnslogs/') and 'Blocked' in r),
    ('umbrella-proxy', 'umbrella-proxy', 'Cisco Umbrella proxy log line', lambda r, a: has(r, 'proxylogs/')),
    ('custom-syslog-sshd', 'custom-buckets', 'Custom bucket: plain-text sshd line', lambda r, a: 'wazuh-rc1-custom' in r and 'sshd' in r),
    ('custom-json', 'custom-buckets', 'Custom bucket: JSON object', lambda r, a: 'wazuh-rc1-custom' in r and 'custom.json' in r),
    ('custom-csv', 'custom-buckets', 'Custom bucket: CSV with header', lambda r, a: 'wazuh-rc1-custom' in r and 'custom-header.csv' in r),
]


def run(args, body=None):
    if body is not None:
        open('/root/rc1/.tb.json', 'w').write(json.dumps(body))
        args = args + ['-d', '@/root/rc1/.tb.json']
    r = subprocess.run(args, capture_output=True, text=True)
    try:
        return json.loads(r.stdout)
    except ValueError:
        return {'_raw': r.stdout[:2000]}


def jkey(e):
    # Alerts on JSON-decoded events omit full_log; the decoded data object is common to both stores.
    return json.dumps(e.get('data'), sort_keys=True) if e.get('data') else e.get('full_log', '')


summary = []
if MODE == 'v4':
    arch = []
    for line in open('/var/ossec/logs/archives/archives.json', errors='replace'):
        try:
            e = json.loads(line)
        except ValueError:
            continue
        if e.get('location') == 'Wazuh-AWS':
            arch.append(e)
    alerts = {}
    for line in open('/var/ossec/logs/alerts/alerts.json', errors='replace'):
        try:
            a = json.loads(line)
        except ValueError:
            continue
        if a.get('location') == 'Wazuh-AWS':
            alerts.setdefault(jkey(a), []).append(a)
    for tid, svc, what, pred in TARGETS:
        hit = next((e for e in arch if pred(e.get('full_log', ''), J(e.get('full_log', '')))), None)
        d = os.path.join(OUT, tid); os.makedirs(d, exist_ok=True)
        rec = {'id': tid, 'service': svc, 'what': what, 'found': bool(hit)}
        if hit:
            raw = hit['full_log']
            open(os.path.join(d, 'raw.txt'), 'w').write(raw)
            json.dump(hit, open(os.path.join(d, '4x-archive.json'), 'w'), indent=1)
            al = alerts.get(jkey(hit), [])
            json.dump(al, open(os.path.join(d, '4x-alerts.json'), 'w'), indent=1)
            rec['4x_alerts'] = [f"{a['rule']['id']} (level {a['rule']['level']}) {a['rule']['description']}" for a in al]
            rec['4x_decoder'] = (hit.get('decoder') or {}).get('name')
        summary.append(rec)
else:
    ints = json.load(open('/root/rc1/ev5/5x-threatintel-integrations.json'))
    ids = {i['document']['metadata']['title']: i['document']['id'] for i in ints
           if 'aws' in ((i.get('document') or {}).get('metadata') or {}).get('title', '').lower()}

    def scroll(index):
        r = run(['/usr/local/sbin/idx', 'POST', f'/{index}/_search?scroll=2m'],
                {'size': 2000, 'query': {'term': {'wazuh.protocol.location': 'Wazuh-AWS'}}})
        out = []
        while (r.get('hits') or {}).get('hits'):
            out += r['hits']['hits']
            r = run(['/usr/local/sbin/idx', 'POST', '/_search/scroll'], {'scroll': '2m', 'scroll_id': r.get('_scroll_id')})
        return out

    evs = scroll('wazuh-events-v5-*')
    fnd = {}
    for h in scroll('wazuh-findings-v5-*'):
        fnd.setdefault(((h['_source'].get('event') or {}).get('original') or ''), []).append(h)
    PREF = sys.argv[3] if len(sys.argv) > 3 else None   # dir of 4.x raws: join on identical bytes
    byraw = {}
    for h in evs:
        byraw.setdefault((h['_source'].get('event') or {}).get('original') or '', h)
    for tid, svc, what, pred in TARGETS:
        hit = None
        pf = os.path.join(PREF, tid, 'raw.txt') if PREF else None
        if pf and os.path.exists(pf):
            hit = byraw.get(open(pf).read())
        joined = hit is not None
        if hit is None:
            hit = next((h for h in evs if pred(((h['_source'].get('event') or {}).get('original') or ''),
                                                J((h['_source'].get('event') or {}).get('original') or ''))), None)
        d = os.path.join(OUT, tid); os.makedirs(d, exist_ok=True)
        rec = {'id': tid, 'service': svc, 'what': what, 'found': bool(hit), 'same_record_as_4x': joined}
        if hit:
            raw = hit['_source']['event']['original']
            open(os.path.join(d, 'raw.txt'), 'w').write(raw)
            json.dump({'_index': hit['_index'], '_source': hit['_source']}, open(os.path.join(d, '5x-event.json'), 'w'), indent=1)
            fs = fnd.get(raw, [])
            json.dump([{'_index': f['_index'], '_source': f['_source']} for f in fs], open(os.path.join(d, '5x-findings.json'), 'w'), indent=1)
            rec['5x_index'] = hit['_index'].split('-v5-')[1].rsplit('-', 1)[0]
            rec['5x_decoders'] = [x for x in ((hit['_source'].get('wazuh') or {}).get('integration') or {}).get('decoders', [])
                                  if x != 'decoder/core-wazuh-message/0']
            rec['5x_findings'] = [f"{(f['_source'].get('wazuh') or {}).get('rule', {}).get('title')} "
                                  f"[{(f['_source'].get('wazuh') or {}).get('rule', {}).get('level')}]" for f in fs]
            rec['5x_event_action_outcome'] = [(hit['_source'].get('event') or {}).get('action'), (hit['_source'].get('event') or {}).get('outcome')]
            lt = {}
            for title, iid in sorted(ids.items()):
                r = run(['/usr/local/sbin/dash', 'POST', '/_plugins/_security_analytics/logtest'],
                        {'document': {'queue': 49, 'location': 'Wazuh-AWS', 'event': raw, 'space': 'standard',
                                      'trace_level': 'ALL', 'integration': iid}})
                json.dump(r, open(os.path.join(d, f'5x-logtest-{title}.json'), 'w'), indent=1)
                det = ((r.get('response') or {}).get('message') or {}).get('detection') or {}
                lt[title] = {'evaluated': det.get('rules_evaluated'), 'matched': det.get('rules_matched'),
                             'matches': [((m.get('rule') or {}).get('title') or m.get('title') or str(m)[:80])
                                         for m in (det.get('matches') or [])]}
            rec['5x_logtest'] = lt
        summary.append(rec)

json.dump(summary, open(os.path.join(OUT, f'{MODE}-targets.json'), 'w'), indent=1)
for r in summary:
    if MODE == 'v4':
        print(f"{r['id']:32s} found={r['found']!s:5s} {r.get('4x_alerts')}")
    else:
        m = {k: v['matched'] for k, v in (r.get('5x_logtest') or {}).items() if v.get('matched')}
        print(f"{r['id']:32s} found={r['found']!s:5s} same4x={r.get('same_record_as_4x')!s:5s} idx={r.get('5x_index')} dec={r.get('5x_decoders')} "
              f"findings={r.get('5x_findings')} lt_matched={m}")
