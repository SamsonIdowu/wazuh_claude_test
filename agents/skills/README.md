# Agent skills

A **lesson** changes what an agent watches for. A **skill** changes what it can do: a procedure it has run well enough, often enough, that keeping it beats re-deriving it. Each agent builds a catalog matched to its own role.

```
agents/skills/<agent>/<skill-name>/
├── SKILL.md          what it does, when to use it, the steps
└── (scripts, templates, checklists the skill needs)
```

Skills are permanent repo assets. This is deliberate: cleanup wipes `results/` and `test/terraform/` after every test run, so a verification script or a generated Terraform pattern worth keeping has to be promoted into a skill **before** cleanup, or it's gone. The tester agents lose the most to this, so they should be the quickest to propose skills.

## When something becomes a skill

Promote when any of these is true:

- The agent has performed the same multi-step procedure **twice**, and would do it a third time.
- The agent wrote a script that verified something (R1/R4 work) and that check will recur on the next doc or post.
- A checklist or sweep was assembled by hand and produced a real finding — the sweep itself is reusable even when the finding isn't.
- You told an agent how you want a recurring task done. That's a skill on the first telling, not the second.

Don't promote a one-off, and don't promote a procedure the agent hasn't actually run successfully.

## Governance (same as lessons)

The agent proposes → QA flags it as a skill candidate in the task retrospective → the **Security Manager** files it under `agents/skills/<agent>/` and logs it in `learning/promoted-changelog.md`. Agents can draft a `SKILL.md`, but only the Security Manager adds it to the catalog, so the catalog doesn't fill up with near-duplicates.

Before writing a new skill, check the existing catalog for something close and extend it instead. Two skills that do nearly the same thing is worse than one imperfect skill.

## SKILL.md format

```markdown
---
name: <skill-name>
description: What it does and when to use it — specific enough that the agent knows whether this is the right skill without opening it.
owner: <agent-name>
created: YYYY-MM-DD
last-verified: YYYY-MM-DD
---

# <Skill name>

## When to use
## Prerequisites
## Steps
## Verification
(For anything a tester agent owns: the command that proves it worked — R1 applies to skills too.)
## Known failure modes
```

Keep `last-verified` current. A skill referencing a Wazuh version, a UI label, or a package URL goes stale, and a stale skill is worse than no skill because it's trusted. Re-verify before reuse on a new major version, and update the date.

## Use platform skills before building your own

Some capabilities already exist as skills in the environment — document, spreadsheet, PDF, and presentation builders, chart and visualization guidance, web research tooling. Check what's available before hand-rolling a procedure for producing a report or a chart. Build a skill here for what's *specific to this pipeline* — Wazuh procedures, the style guide, this repo's test harness — not for general file-format work someone else already solved.

## Seed catalogs by role

Starting points, not a mandate — build the ones the work actually calls for.

**document-tester** — `deploy-baseline-and-verify` (bring up a version, confirm all services with commands per R1) · `essential-procedure-sweep` (installation, service status, dashboard access, credential retrieval, API auth) · `audit-report-build` (assemble the Documentation Audit Report from a verification log) · `cleanup-verification` (destroy, wipe ephemerals, confirm with `git status --short`)

**blogpost-tester** — `claim-extraction` (turn a post into a testable list of claims) · `custom-rule-deployment-test` (deploy a post's rules/decoders and prove the alert fires) · `external-integration-test` (API-dependent posts: security group generation plus reachability checks) · `generated-terraform-scaffold` (the `test/terraform/` pattern for post-specific infra)

**document-reviewer-1** — `style-mechanical-sweep` (grep-based pass for banned words, deprecated terminology, possessives, rule-ID range) · `heading-hierarchy-audit` · `technical-claim-verification` (check claims against official docs, flag what needs a tester)

**document-reviewer-2** — `flow-read-pass` (structured full read for pacing and transitions) · `ai-tell-detection` (the specific patterns: uniform rhythm, filler phrases, listy substitution for explanation, restated conclusions) · `humanization-rewrite-patterns` (before/after pairs that worked)

**qa-agent** — `pipeline-audit-checklist` (was each stage's pass trustworthy) · `brand-fit-review` · `retrospective-authoring` (run the template well and fast) · `promotion-candidate-scan` (spot lessons at the recurrence bar)

**technical-writer-1** — `research-brief-assembly` (gather version-accurate facts before drafting) · `wazuh-task-structure` (the style guide's prerequisites/steps/outcome shape) · `blogpost-outline` (structures that have survived review) · `self-check-sweep` (catch mechanical style issues before Reviewer 1 does)

**technical-writer-2** — `detection-engineering-depth-pass` · `siem-xdr-terminology-precision` · `cloud-security-context-pass` · `depth-vs-filler-cut` (what a senior engineer removes, not just adds)

**security-manager** — `task-dispatch-brief` (a complete, self-contained brief) · `pipeline-status-tracking` · `promotion-workflow` (lesson → drafted instruction → user check → applied → logged) · `skill-filing` (add to catalog, avoid near-duplicates, log it)
