#!/usr/bin/env python3
"""Per-rule alert counts for a rule-ID prefix or group. Run on the manager as root.
Usage: count-alerts.py <group-or-id-prefix> [HH:MM-HH:MM UTC window]"""
import json, sys, collections
key = sys.argv[1]; win = sys.argv[2].split('-') if len(sys.argv) > 2 else None
c = collections.Counter()
for l in open('/var/ossec/logs/alerts/alerts.json'):
    try: a = json.loads(l)
    except ValueError: continue
    r = a['rule']; t = a['timestamp'][11:16]
    if win and not (win[0] <= t < win[1]): continue
    if key in r.get('groups', []) or r['id'].startswith(key):
        c[r['id'] + ' L' + str(r['level'])] += 1
for k in sorted(c): print(k, c[k])
print('TOTAL', sum(c.values()))
