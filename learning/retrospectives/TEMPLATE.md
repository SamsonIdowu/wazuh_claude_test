# Retrospective — <task-id> — <YYYY-MM-DD>

**Piece**: <doc page / blog post title, and location>
**Objective from the brief**: <what this was supposed to achieve>
**Pipeline path taken**: <e.g. Writer 1 → Writer 2 → Reviewer 1 (2 rounds) → Reviewer 2 → Blogpost Tester → QA>
**QA verdict**: approved | sent back (to whom, why)

## What each agent got right

Short, specific. Worth recording because promotion decisions later need to know what's already working.

- **<agent>**: ...

## What a downstream agent had to catch

This is the cross-agent learning signal — an issue caught late that an earlier agent should have caught. One line each: what it was, who caught it, who should have.

- ...

## User feedback on this task

Pull the relevant entries from `learning/feedback-log.md`, and say what each one actually means for each agent involved — not just the quote, the implication.

- ...

## Lessons written from this retrospective

- `learning/lessons/<agent>.md` — <lesson title> (source: downstream-catch | user-feedback | self-observed)

## Skill candidates

Procedures or scripts from this task worth keeping as a reusable skill in `agents/skills/<agent>/`. Note especially anything in `results/` or `test/terraform/` that cleanup is about to delete.

- ...

## Promotion candidates flagged to the Security Manager

Lessons that have now recurred 3+ times, or user feedback phrased as a standing rule.

- ...
