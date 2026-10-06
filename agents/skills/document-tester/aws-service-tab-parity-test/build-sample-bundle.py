#!/usr/bin/env python3
"""Build the redacted sample-event bundle for wazuh/external-devel-requests#6858 from the raw host
evidence. One folder per gap event: the identical raw record as both versions received it, the
4.14.8 alert(s), and the 5.0.0 RC1 event document, findings and logtest replay."""
import json, os, re, shutil

BASE = os.path.dirname(os.path.abspath(__file__))
V4, V5 = os.path.join(BASE, 'raw-host-v4', 'tg4'), os.path.join(BASE, 'raw-host-v5', 'tg5')
OUT = os.path.join(BASE, 'sample-events')

# Run-specific identifiers come from the environment, never from this file:
#   REDACT_TESTER_IP  regex for the tester's egress IP(s), e.g. 203\.0\.113\.\d+
#   REDACT_HOST_IPS   comma-separated public IPs of the Wazuh hosts used in the run
#   REDACT_IAM_USER   the IAM user name that appears in CloudTrail
_tester = os.environ.get('REDACT_TESTER_IP', '').strip()
_hosts = [h.strip() for h in os.environ.get('REDACT_HOST_IPS', '').split(',') if h.strip()]
_user = os.environ.get('REDACT_IAM_USER', '').strip()
if not (_tester and _hosts and _user):
    raise SystemExit('Set REDACT_TESTER_IP, REDACT_HOST_IPS and REDACT_IAM_USER first, or they ship unredacted.')

REDACT = [
    (re.compile(_tester), '<tester-ip>'),
    (re.compile(r'\b(' + '|'.join(map(re.escape, _hosts)) + r')\b'), '<wazuh-host-public-ip>'),
    (re.compile(r'\b' + re.escape(_user) + r'\b'), '<tester-iam-user>'),
    (re.compile(r'\b(AKIA|ASIA)[A-Z0-9]{16}\b'), r'\1<redacted>'),
]


def red(s):
    for rx, rep in REDACT:
        s = rx.sub(rep, s)
    return s


def copy(src, dst):
    if os.path.exists(src):
        with open(src, encoding='utf-8', errors='replace') as f:
            data = f.read()
        with open(dst, 'w', encoding='utf-8', newline='\n') as f:
            f.write(red(data))
        return True
    return False


t4 = {t['id']: t for t in json.load(open(os.path.join(V4, 'v4-targets.json')))}
t5 = {t['id']: t for t in json.load(open(os.path.join(V5, 'v5-targets.json')))}
if os.path.exists(OUT):
    shutil.rmtree(OUT)
os.makedirs(OUT)
index = []
for tid, a in t4.items():
    b = t5.get(tid, {})
    if not a.get('found') and not b.get('found'):
        continue
    d = os.path.join(OUT, tid)
    os.makedirs(d)
    copy(os.path.join(V4, tid, 'raw.txt'), os.path.join(d, 'raw-event.txt'))
    copy(os.path.join(V4, tid, '4x-alerts.json'), os.path.join(d, '4.14.8-alerts.json'))
    copy(os.path.join(V5, tid, '5x-event.json'), os.path.join(d, '5.0-rc1-event.json'))
    copy(os.path.join(V5, tid, '5x-findings.json'), os.path.join(d, '5.0-rc1-findings.json'))
    keep = {'5x-logtest-aws.json'} | ({'5x-logtest-aws-amazon-security-lake.json'} if a['service'] == 'security-lake' else set())
    for f in sorted(os.listdir(os.path.join(V5, tid))) if os.path.isdir(os.path.join(V5, tid)) else []:
        if f in keep:  # replays under integrations that evaluate 0 rules carry no information
            copy(os.path.join(V5, tid, f), os.path.join(d, f.replace('5x-logtest-', '5.0-rc1-logtest-')))
    lt = b.get('5x_logtest') or {}
    index.append({
        'id': tid, 'service': a['service'], 'what': a['what'],
        'same_record_both_versions': b.get('same_record_as_4x', False),
        '4.14.8': {'decoder': a.get('4x_decoder'), 'alerts': [red(x) for x in a.get('4x_alerts') or []]},
        '5.0-rc1': {'indexed': b.get('found', False), 'index': b.get('5x_index'), 'decoders': b.get('5x_decoders'),
                    'event.action/outcome': b.get('5x_event_action_outcome'),
                    'findings': b.get('5x_findings'),
                    'logtest_rules_matched': {k: v.get('matched') for k, v in lt.items() if v.get('evaluated')}},
    })

# Events that never reached a 5.0 index: add the logtest replays that show why.
for tid in ('ecr-critical', 'ecr-summary', 'cw-ssh-failed', 'cw-sudo'):
    d = os.path.join(OUT, tid)
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(os.path.join(V5, tid)):
        if f.startswith('5x-logtest-'):
            copy(os.path.join(V5, tid, f), os.path.join(d, f.replace('5x-logtest-', '5.0-rc1-logtest-')))

json.dump(index, open(os.path.join(OUT, 'index.json'), 'w', encoding='utf-8'), indent=1)

# Final sweep: nothing identifying may survive.
leaks = []
for root, _, files in os.walk(OUT):
    for f in files:
        s = open(os.path.join(root, f), encoding='utf-8', errors='replace').read()
        for rx, _ in REDACT:
            if rx.search(s):
                leaks.append((f, rx.pattern))
print(len(index), 'gap events;', sum(len(fs) for _, _, fs in os.walk(OUT)), 'files; leaks:', leaks[:5])
