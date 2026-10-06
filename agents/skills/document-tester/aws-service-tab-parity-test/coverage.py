#!/usr/bin/env python3
"""Per-type detection coverage for GuardDuty and Security Hub. Usage: coverage.py v4|v5 <out.json>"""
import json, sys, subprocess, collections
MODE, OUT = sys.argv[1], sys.argv[2]
def J(raw):
    try:
        j = json.loads(raw); j = j.get('aws', j) if isinstance(j, dict) else {}
        return j if isinstance(j, dict) else {}
    except Exception:
        return {}
def gd_type(a):
    svc = a.get('service')
    return a.get('type') if isinstance(svc, dict) and svc.get('serviceName') == 'guardduty' else None
def sh_key(a):
    f = a.get('finding') or (a.get('detail') or {}).get('findings', [{}])[0] if isinstance(a.get('detail'), dict) else a.get('finding')
    if not isinstance(f, dict): return None
    pa = f.get('ProductName') or (f.get('ProductFields') or {}).get('aws/securityhub/ProductName') or '?'
    st = (f.get('Compliance') or {}).get('Status') or '-'
    return f"{pa} | compliance={st} | sev={(f.get('Severity') or {}).get('Label')}"
cov = {'guardduty': collections.defaultdict(lambda: [0, 0]), 'securityhub': collections.defaultdict(lambda: [0, 0])}
if MODE == 'v4':
    alerted = set()
    for l in open('/var/ossec/logs/alerts/alerts.json', errors='replace'):
        try: a = json.loads(l)
        except Exception: continue
        if a.get('location') == 'Wazuh-AWS': alerted.add(json.dumps(a.get('data'), sort_keys=True))
    for l in open('/var/ossec/logs/archives/archives.json', errors='replace'):
        try: e = json.loads(l)
        except Exception: continue
        if e.get('location') != 'Wazuh-AWS': continue
        a = J(e.get('full_log', '')); k = json.dumps(e.get('data'), sort_keys=True) in alerted
        t = gd_type(a)
        if t: cov['guardduty'][t][0] += 1; cov['guardduty'][t][1] += k
        s = sh_key(a) if a.get('source') == 'securityhub' else None
        if s: cov['securityhub'][s][0] += 1; cov['securityhub'][s][1] += k
else:
    def scroll(index):
        open('/root/rc1/.c.json', 'w').write(json.dumps({'size': 2000, 'query': {'term': {'wazuh.protocol.location': 'Wazuh-AWS'}}, '_source': ['event.original']}))
        r = json.loads(subprocess.run(['/usr/local/sbin/idx', 'POST', f'/{index}/_search?scroll=2m', '-d', '@/root/rc1/.c.json'], capture_output=True, text=True).stdout)
        out = []
        while r.get('hits', {}).get('hits'):
            out += [h['_source'].get('event', {}).get('original', '') for h in r['hits']['hits']]
            open('/root/rc1/.c.json', 'w').write(json.dumps({'scroll': '2m', 'scroll_id': r['_scroll_id']}))
            r = json.loads(subprocess.run(['/usr/local/sbin/idx', 'POST', '/_search/scroll', '-d', '@/root/rc1/.c.json'], capture_output=True, text=True).stdout)
        return out
    found = set(scroll('wazuh-findings-v5-*'))
    for raw in scroll('wazuh-events-v5-*'):
        a = J(raw); k = raw in found
        t = gd_type(a)
        if t: cov['guardduty'][t][0] += 1; cov['guardduty'][t][1] += k
        s = sh_key(a) if a.get('source') == 'securityhub' else None
        if s: cov['securityhub'][s][0] += 1; cov['securityhub'][s][1] += k
res = {svc: {t: {'events': v[0], 'detected': v[1]} for t, v in sorted(d.items())} for svc, d in cov.items()}
json.dump(res, open(OUT, 'w'), indent=1)
for svc, d in res.items():
    tot = len(d); det = sum(1 for v in d.values() if v['detected'])
    print(f"{svc}: {tot} distinct types, {det} with >=1 detection")
