# Shared lessons

Cross-cutting lessons every agent should know: terminology corrections, recurring technical facts about Wazuh, style-guide clarifications, and standing preferences from the user that apply pipeline-wide.

Every agent reads this file plus its own `learning/lessons/<agent>.md` before starting a task. Entry format is in `learning/README.md`.

---

## 2026-09-24 — 4.x numeric rule IDs do not exist in 5.0
**Source**: self-observed
**Task**: Monitoring Amazon Web Services v5.0 — all service tabs
**Reported by**: document-tester
**What happened**: Every use case in a doc titled "v5.0" cites 4.x numeric rule IDs (80301, 80442, 80492, 80364…). Those IDs are real and fire correctly on 4.14.7, but 5.0 has no numeric rule IDs at all — its rules carry titles ("AWS KMS key created"), a severity tag (low/medium/high) rather than a numeric level, and live at `wazuh.rule` in a finding document, not top-level `rule`. Several services lose coverage entirely in 5.0 rather than being renumbered.
**Lesson**: When writing or reviewing a 5.0 page, do not carry a numeric rule ID over from 4.x content — it is not a renumbering, and the ID will not resolve. State the rule by title, or state which release the use case applies to. When a page must serve both, say so explicitly per use case rather than once at the top.
**Status**: open

## 2026-09-24 — A "v5.0" page can still be a 4.x page in its details
**Source**: self-observed
**Task**: Monitoring Amazon Web Services v5.0 — prerequisites and troubleshooting
**Reported by**: document-tester
**What happened**: Beyond rule IDs, the same page's troubleshooting section is unrunnable on 5.0: the 5.0 manager has no `ossec.log`, no `logall_json`, no `archives/` directory, and its config is `/var/wazuh-manager/etc/wazuh-manager.conf`. Instructions that are correct-but-only-on-4.x are harder to spot than outright errors because they read as normal.
**Lesson**: When a page is relabelled for 5.0, re-verify every filesystem path, config option and diagnostic command against a 5.0 install, not just the feature steps. `/var/ossec/...` paths on a 5.0 host belong to the **agent**; the manager lives under `/var/wazuh-manager/`.
**Status**: open

## 2026-09-29 — An integration that reads a state source and an event stream for the same finding can alert twice
**Source**: downstream-catch
**Task**: Monitoring Kyverno policy violations with Wazuh (blog review + test, 2026-09-29)
**Reported by**: document-reviewer-2 (predicted), blogpost-tester (confirmed)
**What happened**: The Kyverno collector turned each Audit finding into a report alert (101901/101911) and also into event alerts (101903) from both `kyverno-admission` and `kyverno-scan`. Every background re-scan wrote new Event objects with new UIDs, which defeated the UID-based de-duplication. 101903 made up 54 of 94 alerts.
**Lesson**: When a post's integration reads both a state source (reports, inventories) and an event stream (Kubernetes events, audit logs) for the same finding, check whether the finding alerts twice and whether re-scans re-emit it. The screenshot's hit count is the quickest tell. De-duplicate on the finding's identity (policy, resource, result), not on the event object's UID.
**Status**: open

## 2026-09-29 — In 4.x a child rule doesn't inherit its parent's groups; FIM child rules need `syscheck`
**Source**: self-observed
**Task**: Monitoring Kyverno policy violations with Wazuh (blog review + test, 2026-09-29)
**Reported by**: blogpost-tester
**What happened**: Custom rule 101905 (`if_sid 550,553,554`) had the groups `kyverno, kubernetes, kyverno_policy_change` only, with no `syscheck`. Its alerts therefore don't match `rule.groups:syscheck`, the filter the File Integrity Monitoring module uses.
**Lesson**: When writing or reviewing a custom child of a FIM (or any module) rule, include the module's group (for example `syscheck,`) in the child's `<group>`, or its alerts drop out of that module's dashboard.
**Status**: open

## 2026-09-30 — De-duplicate before you filter, or a later state change re-reads old events
**Source**: self-observed
**Task**: Monitoring Kyverno policy violations with Wazuh (revision recheck, 2026-09-30)
**Reported by**: blogpost-tester
**What happened**: The revised collector skipped Audit-policy admission events (`if mode != "enforce": continue`) before recording them in its seen-state. When the live policy switched to Deny, the same events (still inside Kubernetes' one-hour event lifetime) were read again and classified as rejections. That raised six level-10 "refused" alerts for running pods. Moving the state write above the filter fixed it (verified by replay).
**Lesson**: In any polling collector a post ships, record an item as seen before any filter that depends on mutable live state (policy mode, config). Otherwise the same item is re-judged under the new state. When reviewing or testing one, include a state-change step (Audit→Deny, enable→disable) after items have been collected.
**Status**: open

## 2026-10-01 — In 5.0 a rule that matches on paper can still never fire
**Source**: self-observed
**Task**: Monitoring AWS v5.0 — RC1 regression run for external-devel-requests#6858
**Reported by**: document-tester
**What happened**: A console-login failure (integration `aws`) and an sshd failure (integration `system-auth`) both carried exactly the fields `wazuh-generic-1` "Failed authentication attempt" selects, and neither produced a finding. Rules are evaluated against events of their own integration only. Separately, four AWS decoders (`aws-vpcflow`, `aws-elb-logs`, `aws-waf`, `aws-cloudwatch`) look correct in isolation but sit under the wrong parent and can never see the module's event shape.
**Lesson**: When writing, reviewing or testing a 5.0 detection claim, don't infer coverage from a rule's selection or a decoder's check. Prove it with a finding in `wazuh-findings-v5-*` (or logtest scoped to the event's own integration), and check a decoder's `parents` as well as its `check`.
**Status**: open
