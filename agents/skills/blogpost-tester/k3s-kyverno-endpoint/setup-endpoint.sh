#!/bin/bash
# Turn the baseline Ubuntu 24.04 agent into a single-node K3s + Kyverno test endpoint.
# Run on the agent as root:  ssh ... 'sudo bash -s' < setup-endpoint.sh
# Env: KYVERNO_VERSION (default v1.19.1)
set -euo pipefail
KYVERNO_VERSION="${KYVERNO_VERSION:-v1.19.1}"
URL="https://github.com/kyverno/kyverno/releases/download/${KYVERNO_VERSION}/install.yaml"
curl -sfI -o /dev/null "$URL"                              # R2: must be 200 before we apply it
curl -sfL https://get.k3s.io | sh -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
until kubectl get nodes 2>/dev/null | grep -q ' Ready '; do sleep 5; done
k3s --version | head -1
kubectl create -f "$URL" >/dev/null                         # create, not apply: CRDs exceed the annotation limit. Run ONCE.
kubectl -n kyverno wait --for=condition=Ready pod --all --timeout=300s
kubectl -n kyverno get deploy kyverno-admission-controller -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
# Record the defaults that change behaviour (PolicyException handling, resync, scan interval)
for d in admission background reports; do
  echo "$d: $(kubectl -n kyverno get deploy kyverno-$d-controller -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\n' | grep -E 'enablePolicyException|resyncPeriod|backgroundScanInterval' | tr '\n' ' ')"
done
