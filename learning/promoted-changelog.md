# Promoted changelog

Audit trail of every change made to an `agents/*.md` instruction file through the promotion process, and every skill added to `agents/skills/`. Written by the Security Manager agent — the only agent that edits instruction files.

This file is what makes self-improvement reviewable: you can see what each agent was told to start doing, when, and which real lessons drove it.

## Entry format

```markdown
## YYYY-MM-DD — <agent> — <short title>
**Type**: instruction | skill
**Changed**: agents/<name>.md (section: ...) | agents/skills/<agent>/<skill>/SKILL.md (new|updated)
**Rule added / skill purpose**: the exact wording added, or what the skill does.
**Driven by**: learning/lessons/<agent>.md entries dated ..., ... (N recurrences) | user feedback YYYY-MM-DD
**User consulted**: yes (date) | not required (technical/style detail, no scope change)
```

---


## 2026-09-29 — document-reviewer-1, document-reviewer-2 — Read each Google Docs export for what it keeps
**Type**: instruction
**Changed**: agents/document-reviewer-1.md (section: Authoritative source); agents/document-reviewer-2.md (section: Ground truth)
**Rule added**: "**Reading a Google Doc draft.** The Drive exports disagree, so read each one for what it keeps: the **HTML** export for headings, styles, inline formatting and completeness (the markdown export can render the title as `#` and has dropped whole sections), the **plain-text** export for code blocks (real newlines), and a **diff of markdown against plain text** to find unaccepted suggestions, which show up as doubled text. Report open suggestions as must-fix."
**Driven by**: learning/lessons/document-reviewer-1.md and document-reviewer-2.md entries dated 2026-09-29 (Reviewer 2 raised a false "all headings are H1" finding from the markdown export). Also recurring auto-memory notes: two exports disagree (indexer cluster doc, 2026-09-18 and 2026-09-21) and flattened code-block reconstruction (2026-08-05). That makes 3+ recurrences.
**User consulted**: not required (technical detail, no scope change)

## 2026-09-29 — document-reviewer-1 — Automation check on manual procedures
**Type**: instruction
**Changed**: agents/document-reviewer-1.md (section: Does it do justice to the topic)
**Rule added**: "- **Automation**: for any procedure with 3+ manual steps that touch files or config, especially hand-pasting large code blocks, ask whether one script (or a hosted repo with an `install.sh`) could replace them. Don't just name the opportunity: include the script or a working excerpt in the finding."
**Driven by**: user feedback 2026-07-29 (standing rule to always check heading structure and automation opportunities, recorded in auto-memory but not yet in any instruction file; heading hierarchy was already in the checklist). Flagged by QA in the 2026-09-29 Kyverno retrospective.
**User consulted**: not required (applies the user's own standing rule; adds rigor, no scope change)

## 2026-09-29 — blogpost-tester — k3s-kyverno-endpoint
**Type**: skill
**Changed**: agents/skills/blogpost-tester/k3s-kyverno-endpoint/SKILL.md (new), setup-endpoint.sh, wait-policies-ready.sh
**Skill purpose**: Turns the baseline Ubuntu 24.04 agent into a K3s + Kyverno endpoint. Includes a bounded READY poll with an annotate nudge, and records the RBAC-ordering trap, the PolicyException admission/report split, and the background re-scan event duplication, all observed on v1.19.1.
**Driven by**: Kyverno policy-violations blog test 2026-09-29; QA skill candidate (cleanup would otherwise delete the procedure)
**User consulted**: not required

## 2026-09-29 — blogpost-tester — custom-rule-alert-verification
**Type**: skill
**Changed**: agents/skills/blogpost-tester/custom-rule-alert-verification/SKILL.md (new), upload-rules.sh, newalerts.sh, count-alerts.py, dashboard-capture.js
**Skill purpose**: Uploads custom rules through `PUT /rules/files`, records per-step alert evidence from alerts.json, and captures authenticated, filtered dashboard screenshots. Records the child-rule group-inheritance and frequency-composite gotchas.
**Driven by**: Kyverno blog test 2026-09-29 (third blog with custom rules after K8s CIS SCA and AWS IAM); QA skill candidate
**User consulted**: not required

## 2026-09-29 — document-reviewer-1 — rule-test-coverage-map
**Type**: skill
**Changed**: agents/skills/document-reviewer-1/rule-test-coverage-map/SKILL.md (new), coverage-map.py
**Skill purpose**: Maps every custom rule ID to the Testing subsection that claims it and to screenshot evidence, and flags untested rules. Verified against the hand-built map on the Kyverno post (17 rules, 5 untested).
**Driven by**: Reviewer 1 proposal in the 2026-09-29 Kyverno review (second use after K8s CIS SCA); QA skill candidate
**User consulted**: not required

## 2026-09-29 — technical-writer-1 — self-check-sweep
**Type**: skill
**Changed**: agents/skills/technical-writer-1/self-check-sweep/SKILL.md (new), stylecheck.py, proper-nouns.txt, familiar-acronyms.txt; agents/skills/technical-writer-1/README.md
**Skill purpose**: A style gate run before every handoff and on any Doc a writer reviews. It reads markdown, RST, or a Google Docs HTML export (code recognised by font, comment threads skipped), and checks the style guide's mechanical rules and the open writer and shared lessons: rule-ID range, rule descriptions that hedge, rules with no test step, and 5.0 path and rule-ID traps. Errors block; warnings never do. `--allow` waives named rules, and there is no blanket override.
**Driven by**: user feedback 2026-09-29 (adapt the external `blogpost-format` skill to this environment for the writer agents). The source's style gate was rebuilt against `test/Language and formatting style guide for technical writing _ Wazuh.md`, and its em-dash ban was downgraded to a warning because this guide allows em dashes in titles.
**User consulted**: yes (2026-09-29, the user's request)

## 2026-09-29 — technical-writer-2 — google-doc-house-format
**Type**: skill
**Changed**: agents/skills/technical-writer-2/google-doc-house-format/SKILL.md (new), render.py, check_export.py; agents/skills/technical-writer-2/README.md
**Skill purpose**: Gates markdown drafts through self-check-sweep and renders them as house-format HTML for a `create_file` upload. The output has code and note tables, shaded Courier New, prompts on commands only, and measured heading sizes and spacing, and is named and foldered by stage (Research, Blog posts, To be published; folder IDs verified). `check_export.py` then audits the Doc's HTML export, catching bold headings, browser-blue links, unshaded code, code outside tables, and autocorrect damage in commands.
**Driven by**: user feedback 2026-09-29. It adapts the external `blogpost-format` skill. That skill's pandoc renderer and `format.md` spec aren't available here, so the renderer is plain Python with the spec written into it. The import findings the source measured on 2026-08-28 and 08-31 are kept. Not yet run through a real upload and export: see the SKILL.md "Verified, and not" section.
**User consulted**: yes (2026-09-29, the user's request)

## 2026-09-30 — blogpost-tester — custom-rule-alert-verification (updated), k3s-kyverno-endpoint (re-verified)
**Type**: skill
**Changed**: agents/skills/blogpost-tester/custom-rule-alert-verification/dashboard-capture.js (updated); both SKILL.md `last-verified` → 2026-09-30
**Skill purpose**: No change in purpose. On the first reuse, the dashboard capture's single search-bar lookup ran before the Threat Hunting page had rendered it, so the query wasn't typed (509 unfiltered hits). The script now waits up to 60 s for `[data-test-subj="queryInput"]`. `setup-endpoint.sh` ran unchanged on a fresh deployment.
**Driven by**: Kyverno blog recheck 2026-09-30 (second use of both skills)
**User consulted**: not required

## 2026-10-01 — document-tester — aws-service-tab-parity-test (extended)
**Type**: skill
**Changed**: agents/skills/document-tester/aws-service-tab-parity-test/SKILL.md (new "Full regression run with sample events" section, five new failure modes, cleanup list), terraform-rc1/ (main.tf, user_data_v4.sh.tpl, user_data_v5.sh.tpl), collect-all.sh, targets.py, coverage.py, v4-evidence.py, v5-evidence.py, enable-integrations-rc1.sh, build-sample-bundle.py
**Skill purpose**: Extends the parity test to a full 4.x vs 5.0 regression run that hands another team per-gap sample events. One Terraform root builds both hosts plus every AWS source; boot-time enrolment and root-only credential wrappers handle RC1's random credentials; the target extractor pairs both versions on the identical raw record; the bundle builder redacts and keeps the zip under GitHub's attachment limit.
**Driven by**: user request 2026-10-01 (external-devel-requests#6858, RC1 artifacts); third use of the skill
**User consulted**: not required

## 2026-10-06 — blogpost-tester, document-tester — no Terraform in skills
**Type**: instruction
**Changed**: agents/blogpost-tester.md, agents/document-tester.md, agents/skills/README.md (skill-promotion guidance); removed every `.tf`/`.tpl` file from agents/skills/ (blogpost-tester/windows-privesc-endpoint, document-tester/wazuh-indexer-cluster, document-tester/aws-service-tab-parity-test/terraform-rc1/) and rewrote those three SKILL.md files to describe the infrastructure in prose
**Rule**: The repo keeps Terraform only for the baseline Wazuh server and agent in `terraform/`. Skills describe extra infrastructure in their `SKILL.md`, take addresses as variables with no default, and never commit an IP. A committed default had leaked the tester's public IP.
**Driven by**: user feedback 2026-10-06 (standing rule)
**User consulted**: yes (the user's own instruction)
