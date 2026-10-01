# Retrospective: kyverno-blog: 2026-09-29

**Piece**: Blog post draft "Monitoring Kyverno policy violations with Wazuh" (Google Doc `1w-WdwRr8YBMKJG4leWfUurDjaj8w3TBwsJStCMeCECo`). Human-authored: writer Jorest Brice Tankoua Njassep, editor Henadence Anyam.
**Objective from the brief**: The user asked to "review and test this blogpost". The output is an audit report that goes back to the human authors. No rewrite was dispatched, so the writer agents weren't involved.
**Pipeline path taken**: Security Manager (brief) → Document Reviewer 1 ∥ Document Reviewer 2 (run **in parallel**, a deviation from the R1-gates-R2 flow) → Blogpost Tester (**performed by the Security Manager session**, a deviation) → Security Manager consolidated `kyverno-blog-audit.html` → QA
**Test environment**: AWS. Wazuh 4.14.8 all-in-one on Ubuntu 22.04. Ubuntu 24.04 agent with K3s v1.36.4 and Kyverno v1.19.1.
**QA verdict**: Audit deliverable **approved with 15 corrections**, applied by the Security Manager (7 required before delivery). Blog post **not ready to publish**. See `results/qa-signoff.md`.

## What each agent got right

- **Document Reviewer 1**: Judged heading levels from the HTML export and got them right. It noticed the markdown export shows the Title style as `#`. It checked every open editor thread against the current text, cited the style guide by section, and built a rule-to-test coverage map. That map found the five untested rules and the 4-of-11 screenshot gap. It predicted the invalid `kubectl create ns billing dev-apps payments` before any test ran, and it applied the user's standing "can manual steps become a script" rule (S1). Its list of 16 tester claims was specific enough to verify directly.
- **Document Reviewer 2**: Traced every rule against the record the collector actually builds. That independent technical check predicted the duplicate 101903 alerts, the PolicyException `fail→skip` effect, and the missing `syscheck` group on 101905, and the test confirmed all three. It caught the hedge-style rule descriptions and docstrings (the humanization job, done well). It also caught a brand-trust issue: the intro credits Wazuh with collection that a custom script performs.
- **Blogpost Tester (Security Manager session)**: Ran every step verbatim before fixing anything. Counted alerts from `alerts.json` and cross-checked the total (94) against the dashboard. Found a Critical that no review could have found: the READY gate never clears when RBAC is applied after the policies. It proved the fix (a new policy became READY in 5 s). It root-caused the 101903 noise one level deeper than R2 did: background scans write new Event UIDs. It triggered all five untested rules, labeled the one simulated result (101914), and stated plainly that the recurrence lifecycle wasn't verified.
- **Security Manager (consolidation)**: Report structure puts the verdict first and the evidence last. Severities are honest, and the report resolved the reviewers' heading disagreement correctly (R1 was right). Its tone toward the authors is mostly constructive, and it includes a "What checked out" section.

## What a downstream agent had to catch

- **Invalid `kubectl create ns` with three names.** R1 caught it and the tester confirmed it. **R2 missed it**, and its claim 8 even assumes the command works. R2's independent technical check covered code logic but not CLI syntax.
- **RBAC applied after the policies blocks the READY gate.** The tester caught it. R1 saw the ordering but filed it as structure (S1), and R2 did the same (S2). **Both reviewers should have flagged it as a possible functional blocker for the tester**, because a prerequisite that appears after its dependent step is a testable claim, not only a layout issue.
- **Heading hierarchy.** R2 (N6) said the title and sections were all H1, because it judged from the markdown export. R1 and the Security Manager caught this. R2 should have used the HTML export.
- **Doubled text from unaccepted suggestions.** R2 graded it as a wording nit (S11), and R1 graded it as must-fix (M1). R2's severity was wrong: that text appears in the published body. R2's "pass-with-fixes" verdict with five must-fixes also contradicts itself.
- **Narrative claims in the consolidated report beyond the command output.** QA caught these. They include "15-minute resync", the causal rule "Kyverno only re-checks permissions when a policy object changes", `--enablePolicyException=false` in `install.yaml`, "pod names match exactly", "Resources were destroyed after the test" (the infra is still up), and "38 times" without per-step counts that add up to it. **The Security Manager should have caught these.** Because it was also the tester, no independent reader stood between the observations and the prose.
- **Reviewer findings dropped from the report.** R2 M1 (intro misattribution, brand), R1 S13 (Figure 1 uses a generic fox or wolf icon instead of the Wazuh logo), R1 S8/N7 (never shows one enriched alert). QA caught the drops. **The Security Manager should have carried every brand-relevant must-fix through** when consolidating.
- **The report pointed authors at review files in `results/`**, which cleanup deletes. QA caught it. The Security Manager should have attached the content or moved it outside the repo.
- **An unbounded "repeat until READY" wait cost 23 minutes before diagnosis.** The tester caught it itself, late. The fix is a bounded wait with a diagnosis step (lesson filed at the Security Manager's request).
- **The recurrence lifecycle couldn't be verified** because the 101914 back-dating simulation ran first and contaminated the natural recurrence. The tester caught and disclosed it. The fix is to run state-altering simulations last.

## User feedback on this task

- `learning/feedback-log.md` holds no entries for this task, and none at all so far. There was nothing to mark as processed.
- The blogpost-tester lesson on bounded waits was requested in QA's dispatch brief by the Security Manager. If it came from the user, the Security Manager should log the user's exact words in `feedback-log.md`, because a user-originated lesson carries promotion weight that a self-observed one doesn't.
- A user standing rule already sits in auto-memory ("Doc review: structure & automation: always check heading hierarchy and whether manual steps can become a script"). It isn't in any `agents/*.md`. The heading half is covered by R1's instructions, and the automation half isn't in either reviewer's instructions. R1 applied it this time anyway. Flagged below as a promotion candidate.

## Lessons written from this retrospective

- `learning/lessons/technical-writer-1.md` and `technical-writer-2.md`: **Every shipped rule and code path needs a test step that proves it, and the screenshot comes from one clean run** (downstream-catch, merges R1's and R2's drafted lessons)
- `learning/lessons/technical-writer-1.md` and `technical-writer-2.md`: **Rule descriptions say what happened; docstrings say what the function does** (downstream-catch, R2's drafted lesson)
- `learning/lessons/technical-writer-1.md` and `technical-writer-2.md`: **Run the post top to bottom on a clean host, in order, before handing it off** (downstream-catch)
- `learning/lessons/document-reviewer-1.md`: **Judge headings and inline formatting from the HTML export** (self-observed, R1's drafted lesson)
- `learning/lessons/document-reviewer-1.md` and `document-reviewer-2.md`: **A prerequisite placed after the step that needs it goes to the tester as a claim** (downstream-catch)
- `learning/lessons/document-reviewer-2.md`: **Check every command's syntax, not only the code's logic** (downstream-catch)
- `learning/lessons/document-reviewer-2.md`: **Judge headings from the HTML export; the markdown export flattens Title into H1** (downstream-catch)
- `learning/lessons/document-reviewer-2.md`: **Text visible in the published body is must-fix, and must-fixes mean "needs revision"** (downstream-catch)
- `learning/lessons/blogpost-tester.md`: **Bound every "repeat until X" wait, then diagnose** (requested by the Security Manager)
- `learning/lessons/blogpost-tester.md`: **Run state-altering simulations last** (self-observed)
- `learning/lessons/security-manager.md`: **When you also ran the test, separate observed from inferred in the consolidated report** (downstream-catch)
- `learning/lessons/security-manager.md`: **Carry every reviewer must-fix into the consolidated report or drop it on purpose; never point at `results/` in a deliverable** (downstream-catch)
- `learning/lessons/security-manager.md`: **Record pipeline deviations in the brief and reconcile split verdicts** (self-observed by QA)
- `learning/lessons/qa-agent.md`: **Check every narrative claim in a consolidated report against the raw test facts, and every reference to something ephemeral** (self-observed)
- `learning/lessons/shared.md`: **An integration that reads a state source and an event stream for the same finding can alert twice** (downstream-catch, R2's drafted pattern, confirmed by the test)
- `learning/lessons/shared.md`: **In 4.x a child rule doesn't inherit its parent's groups; FIM child rules need `syscheck`** (self-observed, confirmed by the test)

## Skill candidates

For the Security Manager to file. `results/` and `test/terraform/` are about to be wiped, so capture the tester material before cleanup.

- **blogpost-tester / `k3s-kyverno-endpoint`** (new; highest priority, because cleanup deletes the source). Terraform plus user_data for an Ubuntu 24.04 agent host with K3s (pinned, v1.36.4+k3s1 was tested) and Kyverno v1.19.1. It records the known gotchas: apply the `pods/ephemeralcontainers` aggregated RBAC **before** policies; poll READY with a bounded wait, and if it stalls, annotate the policy to force a re-check; the default install warns that PolicyException "would not be processed"; `KUBECONFIG=/etc/rancher/k3s/k3s.yaml`; and `/usr/local/bin/kubectl` is a K3s symlink. It's reusable for any future Kubernetes, Kyverno, or admission-control post.
- **blogpost-tester / `custom-rule-deployment-test`** (seed catalog entry, now with a concrete implementation). It covers three pieces:
  1. Upload rules through `PUT /rules/files/<file>.xml` and reload through `/manager/analysisd/reload`.
  2. Tally alerts per test step: group `alerts.json` by `rule.id` inside each step's time window. That's the table in this report.
  3. Simulate time-based rules by back-dating state files, with the "run it last" caveat.
- **blogpost-tester / `claim-extraction`** (seed): feed it Reviewer 1's coverage map, so the tester starts from the reviewer's claim list instead of re-deriving it.
- **document-reviewer-1 / `rule-test-coverage-map`** (proposed by R1). This is its second use (after the K8s CIS SCA post), so it meets the run-twice bar. The procedure is in `results/review-1.md` §"Proposed skill", which cleanup will delete, so copy it out first.
- **document-reviewer-2 / `rule-by-rule-trace`** (first use). Trace each rule against the exact record the collector or decoder emits. It predicted three confirmed findings. File it if it's used a second time.
- **security-manager / audit-report template**. The `kyverno-blog-audit.html` layout works well for authors: a verdict box with tally pills, a claims-vs-observed table, finding cards, a "What checked out" section, and collapsible evidence. Save a stripped copy as a template before cleanup.
- **qa-agent / `pipeline-audit-checklist`** (seed, first run). This sign-off's checks:
  - narrative claims vs. raw facts
  - dropped reviewer must-fixes
  - references to ephemeral files or infra
  - claims about the "current" state of the infrastructure
  - severity recount
  - tone toward named authors
  - screenshot query vs. caption

  Propose filing after a second run.

## Promotion candidates flagged to the Security Manager

- **None of the lesson-file entries has reached 3+ recurrences yet.** Every lesson file except document-tester's and shared.md's was empty before this task.
- **User standing rule, not yet promoted**: "always check heading hierarchy and whether manual steps can become a script" (user's auto-memory, `doc-review-structure-and-automation`). R1's instructions cover heading hierarchy (line 34). Neither reviewer's instructions mention automation or scripting. The user phrased it as a standing rule ("always"), so it meets the bar now. Proposed wording for both reviewers: "Flag any sequence of manual setup steps (file creation, permissions, systemd units) that could be a script or a hosted install, and suggest it."
- **Near the bar (count lives in the user's auto-memory, not in lesson files, so verify it)**: Google Docs exports misrepresent the source in three different ways. The markdown and text/plain exports disagree on unaccepted suggestions (`google-docs-two-exports-disagree`). Code blocks come out flattened (`google-docs-flattened-codeblock-reconstruction`). In this task, the markdown export made R2 read the Title style as H1. If the count holds, promote one reading rule into both reviewers' instructions: "Headings and inline formatting from HTML, code from plain text, and diff markdown against plain text for suggestions."
- **Watch**: "a blog's setup breaks when run exactly as written". This task had the invalid `create ns` and the READY ordering. The user's auto-memory records similar cases in the Langflow post (nginx bind mismatch, audit key) and the AWS IAM compromise post. If the Security Manager confirms these are the same pattern, the writers' "run the post top to bottom on a clean host" lesson is at 3.
