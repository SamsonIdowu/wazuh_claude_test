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
