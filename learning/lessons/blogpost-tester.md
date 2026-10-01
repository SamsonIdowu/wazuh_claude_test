# Lessons — blogpost-tester

Read this file before starting any task. Entry format is defined in `learning/README.md`.

Keep this file short and current: one lesson per recurring pattern, not one per incident. Lessons marked `promoted` have been written into `agents/blogpost-tester.md` and stay here only as history.

---

## 2026-09-04 — Stray `_override.tf` survived a prior test's cleanup
**Source**: self-observed
**Task**: Clipboard hijacking malware blog test (starting infra deploy found `terraform/wazuh_server_ubuntu24_override.tf` still present)
**Reported by**: blogpost-tester (this session)
**What happened**: A previous blog test (AWS IAM key compromise, per its comment) added `terraform/wazuh_server_ubuntu24_override.tf` to switch the baseline server AMI, per the `_override.tf` mechanism ([[terraform-override-tf-mechanism]] in the repo memory, not this file). Its cleanup ran `terraform destroy` + `rm -rf test/terraform/` but never removed the override file itself, since it doesn't live under `test/terraform/`. It silently carried into this unrelated test's `terraform apply` (which then built on Ubuntu 24.04 instead of the intended 22.04 baseline) — harmless here, but would not always be.
**Lesson**: Before `terraform apply`, run `ls terraform/*_override.tf` to catch a leftover from a prior test. At cleanup, always `rm terraform/*_override.tf` in addition to `rm -rf test/terraform/ results/* test/requirements/*` — override files are the one exception that live outside `test/terraform/`, so the standard sweep misses them. `git status --short` after cleanup should be the actual final check, not just "did the ephemeral dirs get wiped."
**Status**: open

## 2026-09-29 — Bound every "repeat until X" wait, then diagnose
**Source**: self-observed
**Task**: Monitoring Kyverno policy violations with Wazuh (blog review + test, 2026-09-29)
**Reported by**: security-manager (requested at QA dispatch)
**What happened**: The post says to repeat `kubectl get validatingpolicy` until all three policies report `READY=true`. Two policies stayed `READY=false` for 23 minutes after the RBAC manifest before the stall was diagnosed. RBAC aggregation had worked (`can-i` = yes), and any change to the policy object fixed it at once.
**Lesson**: When a step says "repeat until X", poll with a bounded wait: set a timeout from the expected time (a few minutes for a controller reconcile), and record the actual time X took, or that it never came. At the timeout, stop and diagnose: check the status message and the permissions, and try a minimal nudge such as re-apply or annotate. Report the measured time. A wait that never ends is a finding in its own right.
**Status**: open

## 2026-09-29 — Run state-altering simulations last
**Source**: self-observed
**Task**: Monitoring Kyverno policy violations with Wazuh (blog review + test, 2026-09-29)
**Reported by**: blogpost-tester
**What happened**: To trigger the 24-hour reminder rule (101914), the tester back-dated entries in the collector's `seen.json`. The later natural recurrence check (fail → skip → fail) then came through as a reminder, so the recurrence lifecycle couldn't be verified.
**Lesson**: Schedule simulations that edit state files, clocks, or caches after every natural-path check they could affect, or run them on a copy of the state. Note in the plan which checks each simulation contaminates.
**Status**: open
