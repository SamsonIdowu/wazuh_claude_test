# Self-improvement system

This is how the eight agents in `agents/` get better over time — from each other's findings, from your feedback, and from their own past work — without their instructions drifting silently.

## Why it works this way

An agent re-reading an ever-growing log before every task doesn't scale: it gets expensive, and the signal gets buried. So the system separates two things.

**Memory** — `learning/lessons/`, `learning/feedback-log.md`, `learning/retrospectives/` — is what agents read before starting work. Lesson files stay short and current on purpose: one lesson per recurring pattern, not one per incident.

**Promotion** — a lesson that keeps recurring, or feedback from you phrased as a standing rule, gets written into the agent's actual instructions in `agents/<name>.md`. That's the real improvement: the agent's default behavior changes, instead of depending on it reading the right log line that day.

Only the **Security Manager** edits `agents/*.md`, and only through promotion. No agent rewrites its own instructions mid-task.

## The pieces

```
learning/
├── README.md                    ← this file
├── feedback-log.md               verbatim feedback from you — append-only, processed at retrospectives
├── lessons/
│   ├── shared.md                 cross-cutting lessons every agent should know
│   └── <agent>.md                one per agent: what to watch for next time
├── retrospectives/
│   ├── TEMPLATE.md
│   └── <task-id>-<date>.md       one per completed task, written by QA
└── promoted-changelog.md         audit trail of instruction and skill changes, and why

agents/skills/
├── README.md                     the skills system: format, promotion bar, per-agent seed catalogs
└── <agent>/<skill-name>/SKILL.md reusable procedures each agent has built up
```

## How feedback and learning flow

1. **You give feedback, any time, to whichever agent is in front of you.** Whoever receives it logs it verbatim to `learning/feedback-log.md` immediately — piece, date, your exact words, which agent(s) it concerns. Acting on feedback fixes this piece; logging it is what makes the next one better.

2. **Agents catch each other's recurring mistakes.** When a downstream agent notices a pattern — a reviewer seeing the same writer habit twice, a tester finding what a reviewer should have caught, QA finding a reviewer's pass was shallow — it logs a `downstream-catch` entry to the *responsible* agent's lesson file, not its own. Reviewer 1 doesn't just fix Writer 1's draft; it tells Writer 1's lesson file what to watch for.

3. **QA runs a retrospective after every task**, pass or send-back, using `learning/retrospectives/TEMPLATE.md`. It pulls unprocessed feedback tied to the task, records what each agent got right and what got caught late, then writes or updates the relevant `learning/lessons/<agent>.md` entries.

4. **Every agent reads its own lesson file plus `learning/lessons/shared.md` before starting a task.** That's the whole read cost — current lessons, not history.

5. **The Security Manager promotes.** When QA flags a lesson that has recurred 3+ times, or feedback phrased as a standing rule ("always", "never", "from now on"), the Security Manager drafts the specific instruction, checks with you first if it changes an agent's scope, authority, or handoffs, applies it to `agents/<name>.md`, and logs it in `learning/promoted-changelog.md`. Source lessons get marked `promoted`, not deleted.

## Skills

Lessons change what an agent watches for. **Skills** change what it can do — a procedure it has performed well enough, often enough, to be worth keeping verbatim instead of re-deriving. Each agent builds a catalog matched to its role under `agents/skills/<agent>/`, governed the same way lessons are: the agent proposes, QA flags the candidate at retrospective, the Security Manager files it and logs it.

This matters most for the tester agents, because cleanup deliberately wipes `results/` and `test/terraform/` after every run. A verification script worth keeping has to be promoted into a skill *before* cleanup, or the work is gone. See `agents/skills/README.md` for the format, the promotion bar, and each agent's seed catalog.

## Lesson entry format

Used in every file under `learning/lessons/`:

```markdown
## YYYY-MM-DD — <short title>
**Source**: user-feedback | downstream-catch | self-observed
**Task**: <piece or task reference>
**Reported by**: <agent, or "user">
**What happened**: one or two sentences, concrete.
**Lesson**: the rule to apply next time, stated as an instruction.
**Status**: open | promoted (YYYY-MM-DD, into agents/<name>.md)
```

Write lessons instruction-shaped ("when X, do Y") rather than narrative. They need to be actionable on a fast read, not re-tell the story.

## What self-improvement does and doesn't mean here

It means the same mistake, once it's a pattern rather than a one-off, gets caught earlier next time — because the responsible agent reads it, or because it's already in their instructions and they don't need the reminder. It means your feedback lands somewhere immediately and has a guaranteed path to becoming a standing rule when that's what you meant.

It doesn't mean agents rewrite their own instructions unsupervised, and it doesn't mean every one-off note becomes permanent. That's what the recurrence bar and the Security Manager's promotion step are for.
