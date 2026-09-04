`# Agents

This repo's content pipeline is run by eight agents. Each has a full definition (mission, checklists, workflow) in `agents/<name>.md`; this file is the map — who does what, in what order, and how they improve over time.

## Roles and responsibilities

| Agent | File | Responsible for |
|---|---|---|
| Security Manager | `agents/security-manager.md` | Dispatches tasks to the right agent in the right order, tracks status, resolves handoffs. Owns promotion of lessons into instructions and the filing of new skills. The entry point for any new work. |
| Technical Writer 1 | `agents/technical-writer-1.md` | Writes the first draft of documentation or a blog post, thinking like a security engineer. Researches before writing. |
| Technical Writer 2 | `agents/technical-writer-2.md` | Co-authors and elevates Writer 1's draft, thinking like a senior security engineer with SIEM/XDR, cloud security, and deep Wazuh expertise. |
| Document Reviewer 1 | `agents/document-reviewer-1.md` | First-pass review: style guide compliance, technical accuracy, and whether the piece does justice to its topic. |
| Document Reviewer 2 | `agents/document-reviewer-2.md` | Second-pass review: flow, whether the writing reads as human rather than AI-generated, an independent technical check, and improvement suggestions. |
| Document Tester | `agents/document-tester.md` | Deploys real infrastructure and tests Wazuh documentation (4.x and 5.0) end to end — every claim verified with a command. |
| Blogpost Tester | `agents/blogpost-tester.md` | The same functional testing for blog posts, including building any custom infrastructure a post requires. |
| QA | `agents/qa-agent.md` | Final gate: did the piece meet its objective, did the reviewers and testers do their jobs, does it serve Wazuh's brand and marketing goals. Owns the retrospective that feeds the learning system. |

## Flow

```
                              ┌────────────────────┐
                              │  Security Manager   │  ← entry point, defines the brief
                              └──────────┬──────────┘
                                         │ dispatch
                                         ▼
                              ┌────────────────────┐
                              │ Technical Writer 1  │  first draft
                              └──────────┬──────────┘
                                         ▼
                              ┌────────────────────┐
                              │ Technical Writer 2  │  co-authors / elevates
                              └──────────┬──────────┘
                                         ▼
                              ┌────────────────────┐
                    ┌────────▶│ Document Reviewer 1 │  style, technical accuracy, topic coverage
                    │         └──────────┬──────────┘
                    │  fails,            │ passes
                    │  back to           ▼
                    │  writer(s) ┌────────────────────┐
                    ├────────────│ Document Reviewer 2 │  flow, humanization, independent tech check
                    │            └──────────┬──────────┘
                    │                       │ passes
                    │                       ▼
                    │       (if the piece makes functional claims)
                    │            ┌────────────────────┐
                    └────────────│ Document / Blogpost │  verifies claims against a real deployment
                                 │       Tester         │
                                 └──────────┬──────────┘
                                            │ Critical/Important findings → back to writers
                                            ▼
                                 ┌────────────────────┐
                                 │         QA          │  final sign-off
                                 └──────────┬──────────┘
                                            │
                              ┌─────────────┴─────────────┐
                              ▼                            ▼
                        Approved: task closes      Sent back: Security Manager
                        by Security Manager         re-dispatches to the named agent
                              └─────────────┬─────────────┘
                                            ▼
                                 ┌────────────────────┐
                                 │  QA retrospective   │  runs either way — see "Self-improvement"
                                 └────────────────────┘
```

Every stage reports back to the **Security Manager**, which decides where the piece goes next — it's the only agent that moves work between stages. A send-back from Reviewer 1, Reviewer 2, a Tester, or QA always carries a specific finding, never a vague "needs work," and routes to whichever agent owns that finding.

## Self-improvement

The agents learn from each other, from your feedback, and from their own past work through the system in `learning/` — full explanation in `learning/README.md`. In short:

- **Your feedback** gets logged verbatim to `learning/feedback-log.md` the moment you give it, by whichever agent received it — logged even when it's being acted on immediately.
- **Cross-agent learning**: when a downstream agent catches a *recurring* issue in an earlier agent's work, it writes a lesson to that agent's file (`learning/lessons/<agent>.md`), not just a fix to the current draft. Reviewers teach writers; testers teach reviewers; QA teaches everyone.
- **Retrospectives**: QA writes one after every task, pass or send-back, and turns it into lesson entries. Every agent reads its own lesson file plus `learning/lessons/shared.md` before starting work.
- **Promotion**: a lesson that recurs 3+ times, or feedback you phrase as a standing rule, gets written into the agent's actual instructions in `agents/<name>.md` by the Security Manager — checked with you first if it changes an agent's scope or authority, and always logged in `learning/promoted-changelog.md`. That's the real improvement: default behavior changes, rather than depending on an agent reading the right log line.

No agent edits its own instructions. Only the Security Manager does, and only through promotion, so improvement is deliberate and reviewable.

## Skills

Lessons change what an agent watches for; **skills** change what it can do. Each agent builds a catalog of reusable procedures matched to its role under `agents/skills/<agent>/`, with the format, promotion bar, and per-role seed catalogs in `agents/skills/README.md`.

Skills matter most to the tester agents: cleanup deliberately wipes `results/` and `test/terraform/` after every run, so a verification script worth keeping must be promoted into a skill before cleanup, or it's lost and the next test starts from nothing.

## Shared ground truth

All agents work from the same sources, so their outputs stay consistent:

- `test/Language and formatting style guide for technical writing _ Wazuh.md` — the style authority for both writers, both reviewers, and QA
- `test/TEST_SCENARIOS_GUIDE.md` and `test/DOCUMENTATION_TEST_TEMPLATE.md` — the tester agents' procedure and verification rules (R1–R4)
- `test/deployments/*/RUNBOOK.md` — version-specific baseline procedures (4.14.6, 5.0.0, and the upgrade path)
- `learning/lessons/` and `agents/skills/` — accumulated lessons and reusable procedures, read before starting work
- `results/` — where drafts, reviews, and test reports live for the duration of a task (ephemeral, wiped at cleanup per `agent/README.md`)

## Note on where these files live

The agent definitions are in `agents/*.md` and their skills in `agents/skills/`, rather than under `.claude/`, because writes to `.claude/` aren't permitted through this bridge. To register them as native Claude Code subagents and skills, copy `agents/*.md` into `.claude/agents/` and `agents/skills/*` into `.claude/skills/` locally.
