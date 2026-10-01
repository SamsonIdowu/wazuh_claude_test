# Lessons — technical-writer-2

Read this file before starting any task. Entry format is defined in `learning/README.md`.

Keep this file short and current: one lesson per recurring pattern, not one per incident. Lessons marked `promoted` have been written into `agents/technical-writer-2.md` and stay here only as history.

---

## 2026-09-29 — Every shipped rule and code path needs a test step that proves it
**Source**: downstream-catch
**Task**: Monitoring Kyverno policy violations with Wazuh (blog review + test, 2026-09-29)
**Reported by**: document-reviewer-1, document-reviewer-2
**What happened**: The post shipped 17 custom rules and a 469-line collector. Five rules (101912–101916) were never triggered by the Testing section, the script carried legacy-policy paths the post never used, and Figure 2 showed 4 of the 11 rule IDs the Testing section claimed, taken from a noisy 24-hour window (422 hits).
**Lesson**: Map every rule in the rules file to the test step that triggers it and names it. For any rule you can't demonstrate, add one sentence saying why, or cut it. Cut inline code paths that no demonstrated rule uses, or move them to a linked repo. Capture the dashboard screenshot from one clean run, with the time filter set to that run, and make sure it shows every rule ID the Testing section claims.
**Status**: open

## 2026-09-29 — Rule descriptions say what happened; docstrings say what the function does
**Source**: downstream-catch
**Task**: Monitoring Kyverno policy violations with Wazuh (blog review + test, 2026-09-29)
**Reported by**: document-reviewer-2
**What happened**: Rule descriptions carried hedges into every alert ("Outcome inferred from the policy configuration at collection time", "Confirm the replacement was intended"). Docstrings justified design choices to an imagined reviewer, a constant `"outcome": "inferred"` field no rule read was added to every record, and deleted comments left blank lines inside code blocks.
**Lesson**: Write a `<description>` as one sentence stating what happened, with fields, and never the rule's limitations. Write a docstring as one line saying what the function does. Put design caveats in the prose, once. When you answer a review comment, change the prose, not the alert text.
**Status**: open

## 2026-09-29 — Run the post top to bottom on a clean host, in order, before handing it off
**Source**: downstream-catch
**Task**: Monitoring Kyverno policy violations with Wazuh (blog review + test, 2026-09-29)
**Reported by**: blogpost-tester
**What happened**: The first test command (`kubectl create ns billing dev-apps payments`) fails with `exactly one NAME is required, got 3`, which leaves five of six later tests with no namespace. A prerequisite (Kyverno's `pods/ephemeralcontainers` RBAC) came after the policies that needed it, so the post's own "repeat until READY=true" check never cleared. The author's environment had drifted from the steps.
**Lesson**: Before handoff, run every command in the post exactly as printed, in order, on a fresh host, and paste real output under each one. Put every prerequisite before the step that depends on it.
**Status**: open

## 2026-09-30 — After renumbering rules, re-sweep every reference, and re-run the post after any code change
**Source**: downstream-catch
**Task**: Monitoring Kyverno policy violations with Wazuh (revision recheck, 2026-09-30)
**Reported by**: blogpost-tester
**What happened**: The revision removed rule 101903 and shifted every later ID down by one. The "Where" list was updated, but the new admission-evaluation test cites 101912, which is now "PolicyException has expired" (the alert is 101911). Figure 2 was not recaptured, so it now shows three IDs that belong to other rules. The same revision changed the collector to drop duplicate event alerts, and that change introduced false "admission request refused" alerts for pods admitted under Audit. Only a full re-run showed it.
**Lesson**: When you add, remove or renumber a rule, grep the whole draft (tests, "Where" list, figures, captions) for every affected ID and update each one. When a revision changes the collector, decoder or rules, re-run the complete test sequence and recapture the screenshots. Fixing the step a reviewer named isn't enough.
**Status**: open
