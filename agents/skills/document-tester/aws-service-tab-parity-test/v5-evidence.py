#!/usr/bin/env python3
"""awsrc1 5.0 evidence. Per service: event docs (which decoders claimed them), findings, and a
logtest replay of one representative event. Uses the root-only idx/dash wrappers.
Usage: v5-evidence.py <outdir> [--no-logtest]"""
import json, sys, os, subprocess, collections

OUT = sys.argv[1]
LOGTEST = '--no-logtest' not in sys.argv
os.makedirs(OUT, exist_ok=True)


def service(aws):  # same classifier as the 4.x side, kept in sync by copy
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


def classify(src):
    """Service of a v5 event/finding document, or None if it did not come from the AWS module
    (wazuh.protocol.location is "Wazuh-AWS" for everything the module sends). CloudWatch Logs,
    ECR-via-CloudWatch and Security Lake are sent as raw messages, not the {"aws": ...} envelope."""
    if g(src, 'wazuh.protocol.location') != 'Wazuh-AWS':
        return None
    orig = g(src, 'event.original', '') or ''
    try:
        j = json.loads(orig)
    except (ValueError, TypeError):
        j = None
    if isinstance(j, dict) and isinstance(j.get('aws'), dict):
        return service(j['aws'])
    if '"class_uid"' in orig or (isinstance(j, dict) and 'class_uid' in j):
        return 'security-lake'
    if orig.startswith('{"name": "CVE-') or '"UNDEFINED":' in orig or 'imageScanFindings' in orig:
        return 'ecr'
    return 'cloudwatch-logs'


def req(tool, method, path, body=None):
    args = ['/usr/local/sbin/' + tool, method, path]
    if body is not None:
        open('/root/rc1/.body.json', 'w').write(json.dumps(body))
        args += ['-d', '@/root/rc1/.body.json']
    r = subprocess.run(args, capture_output=True, text=True)
    try:
        return json.loads(r.stdout)
    except ValueError:
        return {'_raw': r.stdout[:2000]}


def scroll(index, src_fields=None):
    body = {'size': 2000, 'query': {'match_all': {}}}
    if src_fields:
        body['_source'] = src_fields
    r = req('idx', 'POST', f'/{index}/_search?scroll=2m', body)
    hits = []
    while True:
        h = (r.get('hits') or {}).get('hits') or []
        if not h:
            break
        hits += h
        sid = r.get('_scroll_id')
        r = req('idx', 'POST', '/_search/scroll', {'scroll': '2m', 'scroll_id': sid})
    return hits


def g(d, path, default=None):
    for p in path.split('.'):
        if not isinstance(d, dict):
            return default
        d = d.get(p)
    return d if d is not None else default


# ---- ruleset dumps (proof of what RC1 ships) ----
for name in ('integrations', 'decoders', 'rules', 'kvdbs', 'policies'):
    docs = scroll(f'wazuh-threatintel-{name}-a')
    json.dump([h['_source'] for h in docs], open(os.path.join(OUT, f'5x-threatintel-{name}.json'), 'w'))
    print(f'dump {name}: {len(docs)}')

ints = json.load(open(os.path.join(OUT, '5x-threatintel-integrations.json')))
aws_ids = {g(i, 'document.metadata.title'): g(i, 'document.id') for i in ints
           if 'aws' in (g(i, 'document.metadata.title', '') or '').lower()}
json.dump({t: {'id': aws_ids[t], 'enabled': next(g(i, 'document.enabled') for i in ints if g(i, 'document.metadata.title') == t)}
           for t in aws_ids}, open(os.path.join(OUT, '5x-aws-integrations-state.json'), 'w'), indent=1)
AWSID = aws_ids.get('aws')
print('aws integrations:', aws_ids)

# ---- events ----
events = scroll('wazuh-events-v5-*')
by = collections.defaultdict(list)
for h in events:
    s = classify(h['_source'])
    if s:
        by[s].append(h)

# ---- findings ----
findings = scroll('wazuh-findings-v5-*')
fby = collections.defaultdict(list)
for h in findings:
    s = classify(h['_source'])
    if s:
        fby[s].append(h)

summary = {}
for s in sorted(set(by) | set(fby)):
    d = os.path.join(OUT, s.replace(':', '_').replace('/', '_'))
    os.makedirs(d, exist_ok=True)
    evs = by[s]
    dec = collections.Counter(', '.join(x for x in (g(h['_source'], 'wazuh.integration.decoders', []) or [])) or '<none>' for h in evs)
    idxs = collections.Counter(h['_index'].rsplit('-', 1)[0] for h in evs)
    with open(os.path.join(d, '5x-events-sample.jsonl'), 'w') as f:
        for h in evs[:5]:
            f.write(json.dumps({'_index': h['_index'], '_source': h['_source']}) + '\n')
    ftal = collections.Counter((g(h['_source'], 'wazuh.rule.title'), str(g(h['_source'], 'wazuh.rule.level'))) for h in fby[s])
    seen = set()
    with open(os.path.join(d, '5x-findings-sample.jsonl'), 'w') as f:
        for h in fby[s]:
            t = g(h['_source'], 'wazuh.rule.title')
            if t in seen:
                continue
            seen.add(t)
            f.write(json.dumps({'_index': h['_index'], '_source': h['_source']}) + '\n')
    lt_summary = None
    if LOGTEST and evs and AWSID:
        orig = g(evs[0]['_source'], 'event.original', '')
        lt_summary = {}
        for title, iid in sorted(aws_ids.items()):  # logtest is scoped to ONE integration per call
            body = {'document': {'queue': 49, 'location': 'Wazuh-AWS', 'event': orig, 'space': 'standard',
                                 'trace_level': 'ALL', 'integration': iid}}
            r = req('dash', 'POST', '/_plugins/_security_analytics/logtest', body)
            json.dump(r, open(os.path.join(d, f'5x-logtest-{title}.json'), 'w'), indent=1)
            m = g(r, 'response.message', {}) or {}
            traces = g(m, 'normalization.asset_traces', []) or []
            lt_summary[title] = {
                'decoders_passed': [t.get('asset') for t in traces if t.get('success')],
                'detection': {k: g(m, 'detection.' + k) for k in ('status', 'rules_evaluated', 'rules_matched')},
                'matches': [g(x, 'rule.title') or g(x, 'title') or x for x in (g(m, 'detection.matches', []) or [])][:10],
            }
    summary[s] = {'events': len(evs), 'indices': dict(idxs), 'decoders': dict(dec.most_common(6)),
                  'findings': len(fby[s]), 'finding_titles': {f'{k[0]} [{k[1]}]': n for k, n in ftal.items()},
                  'logtest': lt_summary}

json.dump(summary, open(os.path.join(OUT, '5x-summary.json'), 'w'), indent=1)
for s, v in summary.items():
    lt = v['logtest'] or {}
    rm = {t: (x.get('detection') or {}).get('rules_matched') for t, x in lt.items()}
    print(f"{s:20s} events={v['events']:6d} findings={v['findings']:5d} rules_matched={rm} "
          f"decoders={list(v['decoders'])[:2]}")
