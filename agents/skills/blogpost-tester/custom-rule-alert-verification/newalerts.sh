#!/bin/bash
# Print alerts added to alerts.json since the last call (per-step evidence), filtered by rule group.
# Run on the manager as root:  GROUP=kyverno bash newalerts.sh   (also always shows syscheck alerts)
# First call just sets the marker. Use one call per test step so counts map to steps.
M=/root/.alertmark-${GROUP:-custom}; F=/var/ossec/logs/alerts/alerts.json
N=$(wc -l < $F); P=$(cat $M 2>/dev/null || echo 0)
echo "== $(date -u +%T) alerts.json lines $P -> $N"
sed -n "$((P+1)),${N}p" $F | GROUP="${GROUP:-custom}" python3 -c "
import json,sys,os
g0=os.environ['GROUP']
for l in sys.stdin:
    try: a=json.loads(l)
    except Exception: continue   # a line can be mid-write
    r=a['rule']; g=r.get('groups',[])
    if g0 in g or 'syscheck' in g:
        print(' ', a['timestamp'][11:19], r['id'], 'L%s'%r['level'], r['description'][:230], '|', a.get('syscheck',{}).get('path',''))
"
echo $N > $M
