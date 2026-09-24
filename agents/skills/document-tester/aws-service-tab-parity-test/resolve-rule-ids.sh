#!/bin/bash
# Resolve every rule ID a documentation page cites against the ruleset actually
# shipped on this host. A page that cites an ID which does not exist is a finding,
# and it is invisible unless you check — the alert simply never appears and the
# reader assumes their setup is wrong.
#
#   Usage (4.x):  resolve-rule-ids.sh 80301 80302 80303 80352 80354 ...
#
# On 5.0 there are no numeric rule IDs; use list-aws-rules.sh instead.

set -uo pipefail

F=/var/ossec/ruleset/rules/0350-amazon_rules.xml
[ -r "$F" ] || { echo "FATAL: $F not readable (run with sudo, or this is a 5.0 host)"; exit 1; }
[ $# -gt 0 ] || { echo "usage: resolve-rule-ids.sh <id> [id...]"; exit 1; }

python3 - "$F" "$@" <<'PY'
import re, sys
path, ids = sys.argv[1], sys.argv[2:]
x = open(path, encoding='utf-8', errors='replace').read()
missing = []
for rid in ids:
    m = re.search(r'<rule id="%s"[^>]*>(.*?)</rule>' % rid, x, re.S)
    if not m:
        print(f"{rid}  *** NOT PRESENT IN RULESET ***")
        missing.append(rid)
        continue
    body = m.group(1)
    d = re.search(r'<description>(.*?)</description>', body, re.S)
    lvl = re.search(r'level="(\d+)"', m.group(0))
    desc = ' '.join((d.group(1) if d else '').split())
    print(f"{rid}  level={lvl.group(1) if lvl else '?'}  {desc}")
print()
print(f"{len(ids) - len(missing)}/{len(ids)} cited rule IDs exist."
      + (f"  MISSING: {', '.join(missing)}" if missing else ""))
PY
