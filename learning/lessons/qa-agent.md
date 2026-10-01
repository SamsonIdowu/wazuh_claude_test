# Lessons — qa-agent

Read this file before starting any task. Entry format is defined in `learning/README.md`.

Keep this file short and current: one lesson per recurring pattern, not one per incident. Lessons marked `promoted` have been written into `agents/qa-agent.md` and stay here only as history.

---

## 2026-09-29 — Check every narrative claim in a consolidated report against the raw test facts
**Source**: self-observed
**Task**: Monitoring Kyverno policy violations with Wazuh (blog review + test, 2026-09-29)
**Reported by**: qa-agent
**What happened**: The audit report's tables matched the test output, but its prose carried unbacked claims (an unsourced resync interval, a causal rule stated as fact, "exactly" on randomized pod names, "Resources were destroyed" while the infra was up) and an offer to share files that cleanup deletes.
**Lesson**: When you audit a consolidated deliverable, check the prose, not only the tables. List each factual sentence and match it to a command output or test fact. Flag anything about the current state of the infrastructure, and any reference to `results/` or to live hosts. Recount the verdict tallies against the finding cards and the tables, for example whether a per-step table sums to the stated total.
**Status**: open
