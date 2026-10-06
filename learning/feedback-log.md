# Feedback log

Verbatim feedback from the user, logged the moment it's given by whichever agent received it. Append-only. Processed during retrospectives by the QA agent.

Log feedback here even when you're about to act on it immediately — acting on it fixes this piece, logging it is what makes the next piece better.

## Entry format

```markdown
## YYYY-MM-DD — <piece/task>
**From**: user
**Concerns**: <agent(s)>
**Feedback (verbatim)**: "..."
**Processed**: no | yes (YYYY-MM-DD, retrospective: <link>)
```

Keep the feedback verbatim. Paraphrasing drops the part that mattered — the specific word the user objected to, the exact phrasing they preferred.

---

## 2026-09-29 — Writer skills from the blogpost-format skill
**From**: user
**Concerns**: technical-writer-1, technical-writer-2
**Feedback (verbatim)**: "instead of using this skill file, copy its contents and adapt it to my environment and use it to update existing skills for my writer agents so that they can review better."
**Processed**: yes (2026-09-29, filed as skills technical-writer-1/self-check-sweep and technical-writer-2/google-doc-house-format; see learning/promoted-changelog.md)

## 2026-10-01 — Monitoring AWS v5.0, RC1 regression run for external-devel-requests#6858
**From**: user
**Concerns**: document-tester, security-manager
**Feedback (verbatim)**: "Extract sample logs from the servers for every test done and provide them in the report to satisfy this issue: https://github.com/wazuh/external-devel-requests/issues/6858 Use the RC1 attached artifacts. Ensure to compare 4x against 5.0 just to see the missing detections from 4.x to 5.0 and the log events that shows it. More like Regression testing."
**Processed**: yes (2026-10-01, retrospective: learning/retrospectives/2026-10-01-aws-rc1-regression.md)
