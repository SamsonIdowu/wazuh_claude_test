#!/bin/bash
# Bounded READY poll for Kyverno ValidatingPolicies. Never wait open-ended on a "repeat until" step.
# Usage: wait-policies-ready.sh [timeout_seconds=180] [--nudge]
#   --nudge: if still not ready at timeout, annotate each not-ready policy (forces Kyverno to re-check RBAC) and poll 30s more.
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
T=${1:-180}; START=$(date +%s)
while :; do
  NR=$(kubectl get validatingpolicy -o jsonpath='{range .items[?(@.status.conditionStatus.ready==false)]}{.metadata.name}{" "}{end}')
  [ -z "$NR" ] && { echo "all READY after $(( $(date +%s)-START ))s"; exit 0; }
  [ $(( $(date +%s)-START )) -ge "$T" ] && break; sleep 10
done
echo "NOT READY after ${T}s: $NR"
for p in $NR; do kubectl get validatingpolicy "$p" -o jsonpath='{.status.conditionStatus.conditions[?(@.status=="False")].message}'; echo; done
if [ "$2" = "--nudge" ]; then
  for p in $NR; do kubectl annotate validatingpolicy "$p" wazuh-test/recheck="$(date +%s)" --overwrite; done
  sleep 30; kubectl get validatingpolicy
fi
exit 1
