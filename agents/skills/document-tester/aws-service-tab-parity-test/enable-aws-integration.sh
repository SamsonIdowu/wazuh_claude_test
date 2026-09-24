#!/bin/bash
# Wazuh 5.0 only. Performs the doc's "Enable AWS integration on the Wazuh dashboard"
# step (Security Analytics > Overview > search "aws" > Actions > Enable) over the API,
# and works around the failure that step hits on a fresh all-in-one install.
#
#   Usage: enable-aws-integration.sh [integration-title] [admin-user] [admin-pass]
#
# Without this, the aws integration stays enabled:false, nothing is decoded, and the
# wodle logs look perfectly healthy while no alert is ever produced.

set -uo pipefail

TITLE="${1:-aws}"
U="${2:-admin}"
P="${3:-admin}"
IDX=https://localhost:9200
DASH=https://localhost:443

echo "== locating the '$TITLE' integration =="
ID=$(curl -sk -u "$U:$P" "$IDX/wazuh-threatintel-integrations-a/_search?size=300" \
      -H 'Content-Type: application/json' \
      -d '{"_source":["document.metadata.title","document.enabled"]}' \
     | python3 -c "
import sys,json
d=json.load(sys.stdin)
for h in d['hits']['hits']:
    doc=h['_source'].get('document',{})
    if (doc.get('metadata') or {}).get('title')=='$TITLE':
        print(h['_id']); break
")
[ -n "$ID" ] || { echo "FATAL: no integration titled '$TITLE'"; exit 1; }
echo "id=$ID"

# The Security Analytics backend needs this index to exist before it will accept an
# integration update. On a fresh install nothing has created it yet, and the enable
# fails with: no such index [.opensearch-sap-detectors-config]
if ! curl -sk -u "$U:$P" "$IDX/.opensearch-sap-detectors-config" | grep -q detectors-config; then
  echo "== creating missing .opensearch-sap-detectors-config =="
  curl -sk -u "$U:$P" -X PUT "$IDX/.opensearch-sap-detectors-config" \
    -H 'Content-Type: application/json' \
    -d '{"settings":{"index.hidden":true,"number_of_shards":1,"number_of_replicas":0}}'
  echo
  sleep 3
fi

echo "== building the update body from the current document =="
curl -sk -u "$U:$P" "$IDX/wazuh-threatintel-integrations-a/_doc/$ID" | python3 -c "
import sys,json
d=json.load(sys.stdin)['_source']
doc=d['document']; doc['enabled']=True
json.dump({'document':doc,'space':d.get('space',{'name':'standard'})},open('/tmp/int-body.json','w'))
print('title',doc['metadata']['title'],'decoders',len(doc.get('decoders',[])),'rules',len(doc.get('rules',[])))
"

echo "== PUT (note: this endpoint has no GET; a GET returns 404 and that is normal) =="
curl -sk -u "$U:$P" -X PUT "$DASH/_plugins/_security_analytics/integrations/$ID" \
  -H 'Content-Type: application/json' -H 'osd-xsrf: true' -d @/tmp/int-body.json
echo

sleep 8
echo "== verification (R1) =="
curl -sk -u "$U:$P" "$IDX/wazuh-threatintel-integrations-a/_doc/$ID?_source_includes=document.enabled,document.metadata.title"
echo
echo "Now restart the indexer, then the manager, and wait for:"
echo "  [CM::Sync] Successfully synchronized space 'standard'   in /var/wazuh-manager/logs/wazuh-manager.log"
