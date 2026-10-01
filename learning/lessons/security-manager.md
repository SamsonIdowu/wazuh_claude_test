# Lessons — security-manager

Read this file before starting any task. Entry format is defined in `learning/README.md`.

Keep this file short and current: one lesson per recurring pattern, not one per incident. Lessons marked `promoted` have been written into `agents/security-manager.md` and stay here only as history.

---

## 2026-09-29 — When you also ran the test, separate observed from inferred in the consolidated report
**Source**: downstream-catch
**Task**: Monitoring Kyverno policy violations with Wazuh (blog review + test, 2026-09-29)
**Reported by**: qa-agent
**What happened**: The same session ran the test and wrote the audit report, and some narrative went beyond the command output: "past Kyverno's 15-minute resync", "Kyverno only re-checks permissions when a policy object changes", "pod names match … exactly" (they have random suffixes), and "Resources were destroyed after the test" while the infrastructure was still up.
**Lesson**: In a consolidated report, state as fact only what a command showed. Phrase inferences as "in this run…" or attribute them ("from the collector code"). Write any sentence about the state of the infrastructure after that state is true. When you are both tester and consolidator, re-read the report against the raw output before handing it to QA.
**Status**: open

## 2026-09-29 — Carry every reviewer must-fix into the consolidated report, and never point at `results/`
**Source**: downstream-catch
**Task**: Monitoring Kyverno policy violations with Wazuh (blog review + test, 2026-09-29)
**Reported by**: qa-agent
**What happened**: The report dropped Reviewer 2's M1 (the intro credits Wazuh with collection a custom script performs), Reviewer 1's Figure 1 finding (a generic fox or wolf icon instead of the Wazuh logo), and the unshown enriched alert. It also told the authors to "ask for" review files that cleanup deletes.
**Lesson**: When consolidating, go through each reviewer's must-fix list and either include each item or note why it was dropped. Brand-relevant items are never dropped silently. Put anything the authors need (such as the editor-thread status table) in the deliverable itself, or copy it outside the repo before cleanup. Never refer to `results/` in a deliverable.
**Status**: open

## 2026-09-29 — Record pipeline deviations in the brief and reconcile split verdicts
**Source**: self-observed
**Task**: Monitoring Kyverno policy violations with Wazuh (blog review + test, 2026-09-29)
**Reported by**: qa-agent
**What happened**: Reviewers 1 and 2 ran in parallel to save time, and the Security Manager acted as the tester. The reviewers returned opposite verdicts (needs revision / pass-with-fixes), and nobody reconciled them before consolidation. Nobody independent checked the tester's prose.
**Lesson**: When you run the reviewers in parallel or take a role yourself, say so in the brief and in the report's method section. Before consolidating, reconcile any split reviewer verdict and state the reason. When you took the tester role, ask QA to check the report's claims against the raw output.
**Status**: open
