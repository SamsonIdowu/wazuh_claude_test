---
name: k3s-kyverno-endpoint
description: Turn the baseline Ubuntu 24.04 agent into a single-node K3s + Kyverno test endpoint, with the RBAC-ordering trap, a bounded READY poll, and the Kyverno defaults that change test outcomes (PolicyException handling, background re-scan events). Use for any blog post or doc that runs Kyverno (or another admission controller) on K3s next to a Wazuh agent.
owner: blogpost-tester
created: 2026-09-29
last-verified: 2026-09-30
---

# K3s + Kyverno test endpoint

Built on the "Monitoring Kyverno policy violations with Wazuh" blog test: K3s v1.36.4+k3s1,
Kyverno v1.19.1, Wazuh agent 4.14.8, Ubuntu 24.04.5, t3.large.

## When to use
The post needs a Kubernetes cluster on the monitored endpoint and uses Kyverno ValidatingPolicy,
PolicyReports, PolicyViolation events or PolicyExceptions.

## Prerequisites
- Baseline `terraform/` with `agent_instance_type = "t3.large"` or larger. K3s + Kyverno's four
  controllers are too much for t3.medium alongside the agent.
- The agent AMI is already Ubuntu 24.04. No extra security-group rules are needed; the API is local.

## Steps
1. `ssh … 'sudo bash -s' < setup-endpoint.sh` (optionally `KYVERNO_VERSION=v1.19.1`). This checks the
   release URL returns 200, installs K3s, runs `kubectl create -f install.yaml` **once** (use
   `create`, not `apply`; a second run just prints about 70 AlreadyExists errors), waits for the pods,
   and prints the controller flags that change behavior.
2. Follow the post's own steps verbatim. When the post has a "repeat until READY" gate, run
   `wait-policies-ready.sh 180` instead of waiting indefinitely. On timeout it prints each policy's
   failing condition. `--nudge` annotates the not-ready policies to force a re-check. Record the
   timeout as a finding; don't just nudge and move on.
3. Drive multi-line shell steps by writing a local script and piping it:
   `ssh … 'sudo bash -s' < step.sh`. Nested quoting through `ssh "sudo -i bash -c \"…\""` collapses
   newlines and silently runs garbage.

## Verification
- `kubectl -n kyverno get pods`: 4/4 Running. Pod-template hashes match across installs of the same
  release (`687f76f7f4`, `66bb47c44c`, `6d5587df98`, `7db7dcdd79` for v1.19.1). The pod suffixes don't.
- `kubectl get validatingpolicy`: READY=true for every policy before any test step.

## Known failure modes (all observed 2026-09-29, v1.19.1)
- **RBAC after policies means READY=false indefinitely.** A policy matching `pods/ephemeralcontainers`
  reports `missing permissions` if created before the aggregated ClusterRole
  (`rbac.kyverno.io/aggregate-to-*: "true"`) exists. Applying the RBAC afterwards does **not** refresh
  the status: still false at 23 min and at 16.5 min (past `--resyncPeriod=15m`), and re-applying
  unchanged manifests doesn't help either. Fix it by changing the object
  (`kubectl annotate validatingpolicy <p> recheck=$(date +%s) --overwrite`) or with
  `kubectl -n kyverno rollout restart deploy`. Reports are generated **anyway** while READY=false, so
  it's a gate problem, not a functional one.
- **PolicyException: admission and reports disagree.** `install.yaml` sets
  `--enablePolicyException=false` on the admission, background and reports controllers, and
  `kubectl apply` warns `PolicyException resources would not be processed until it is enabled.`
  Admission ignores the exception (a matching pod is still denied), but background reports honor it
  (results go fail → skip, and back within about 20 s of deleting the exception).
- **Background re-scans mint new Event objects.** Any policy or exception change re-scans, and every
  re-scan creates new `PolicyViolation` events with new UIDs (component `kyverno-scan`). Anything
  that de-duplicates events by UID re-alerts on old findings. Expect event volume per step to be
  roughly 2× the findings (admission + scan).
- ClusterPolicyReport updates lag: about 85 s from `kubectl label` to the report showing pass.
- `kubectl create ns a b c` is invalid (`exactly one NAME is required`). Loop instead.
- The denial message is prefixed `error when creating "<file>|STDIN":`. After a policy's admission is
  toggled, the webhook name can gain a hash suffix (`vpol.validate.kyverno.svc-fail-73b04d8c`).

## Added 2026-09-30 (third round, fresh stack)
- With the RBAC applied before the policies, all three were READY=true 1 s after `apply`.
- Reports take about 20 s to appear after a namespace or pod is created, and about 20 s to flip after
  a label. Run "list the reports" steps only after a bounded wait.
- **Kyverno keeps expired PolicyExceptions** (still present 150 s after `expiresAt`). A collector that
  checks expiry on a timer only sees it while the object exists. A step that deletes the exception
  right after the expiry time usually beats the next run, so the "expired" alert never fires. Test it
  by recording the last collector run versus the expiry and the delete times.
- Deleting and recreating a policy gives it a new UID. Anything keyed on the policy UID re-reports all
  of that policy's open findings as new.
- After `k3s-uninstall.sh` and a reinstall, clear root's `~/.kube/cache` (and any service account's
  `$HOME/.kube`). A stale discovery cache turns "no such resource type" into a confusing
  `Error from server (NotFound): Unable to list ...` under a printed column header.

## Cleanup
`terraform destroy` removes everything. Nothing lives outside the agent instance.
