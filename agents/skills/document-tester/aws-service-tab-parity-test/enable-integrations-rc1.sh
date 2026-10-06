#!/bin/bash
# Wazuh 5.0: the doc's "Enable AWS integration on the Wazuh dashboard" step (Security Analytics >
# Overview > search > Actions > Enable) done over the API for every integration the doc lists.
# Uses the root-only idx/dash wrappers, so no credential appears here.
set -uo pipefail
TITLES="${*:-aws aws-amazon-security-lake aws-bedrock aws-fargate aws-firehose}"

if [ "$(idx GET /.opensearch-sap-detectors-config -o /dev/null -w '%{http_code}')" != "200" ]; then
  echo "== .opensearch-sap-detectors-config missing (SA bootstrap did not run) - creating it =="
  idx PUT /.opensearch-sap-detectors-config -d '{"settings":{"index.hidden":true,"number_of_shards":1,"number_of_replicas":0}}'; echo
  sleep 15
fi

idx POST '/wazuh-threatintel-integrations-a/_search?size=300' \
  -d '{"_source":["document.metadata.title","document.enabled","document.id"]}' > /root/rc1/.ints.json

for T in $TITLES; do
  ID=$(python3 -c "
import json,sys
for h in json.load(open('/root/rc1/.ints.json'))['hits']['hits']:
    d=h['_source'].get('document',{})
    if (d.get('metadata') or {}).get('title')=='$T': print(h['_id']); break")
  if [ -z "$ID" ]; then echo "$T: NOT PRESENT in this build"; continue; fi
  idx GET "/wazuh-threatintel-integrations-a/_doc/$ID" | python3 -c "
import sys,json
d=json.load(sys.stdin)['_source']; doc=d['document']; was=doc.get('enabled'); doc['enabled']=True
json.dump({'document':doc,'space':d.get('space',{'name':'standard'})},open('/root/rc1/.int-body.json','w'))
print('$T', 'was_enabled=%s decoders=%d rules=%d' % (was, len(doc.get('decoders',[])), len(doc.get('rules',[]))))"
  code=$(dash PUT "/_plugins/_security_analytics/integrations/$ID" -d @/root/rc1/.int-body.json -o /root/rc1/.put.out -w '%{http_code}')
  echo "   PUT -> HTTP $code $(head -c 160 /root/rc1/.put.out)"
done

sleep 8
echo "== verification (R1) =="
idx POST '/wazuh-threatintel-integrations-a/_search?size=300' \
  -d '{"_source":["document.metadata.title","document.enabled"]}' | python3 -c "
import json,sys
want=set('$TITLES'.split())
for h in json.load(sys.stdin)['hits']['hits']:
    d=h['_source']['document']; t=(d.get('metadata') or {}).get('title')
    if t in want: print('  ',t,'enabled=',d.get('enabled'))"
