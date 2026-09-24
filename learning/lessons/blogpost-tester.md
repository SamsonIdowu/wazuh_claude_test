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
