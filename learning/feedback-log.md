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
