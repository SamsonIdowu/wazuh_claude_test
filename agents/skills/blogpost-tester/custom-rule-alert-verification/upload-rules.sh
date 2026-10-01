#!/bin/bash
# Upload a custom rules file through the Wazuh 4.x API (what the dashboard's Save button calls),
# restart the manager, and list what loaded. Run on the manager as root.
# Usage: API_PW='<wazuh-wui password>' upload-rules.sh /tmp/<file>.xml
set -euo pipefail
F="$1"; N=$(basename "$F")
TOK=$(curl -sk -u "wazuh-wui:${API_PW}" -X POST 'https://localhost:55000/security/user/authenticate?raw=true')
curl -sk -X PUT -H "Authorization: Bearer $TOK" -H 'Content-Type: application/octet-stream' \
  --data-binary @"$F" "https://localhost:55000/rules/files/${N}?overwrite=true" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['message']); sys.exit(d['error'])"
curl -sk -X PUT -H "Authorization: Bearer $TOK" 'https://localhost:55000/manager/restart' >/dev/null
sleep 25; systemctl is-active wazuh-manager
curl -sk -H "Authorization: Bearer $TOK" "https://localhost:55000/rules?filename=${N}&limit=500&select=id,level" \
  | python3 -c "import json,sys; d=json.load(sys.stdin)['data']; print(d['total_affected_items'],'rules loaded:',[(i['id'],i['level']) for i in d['affected_items']])"
