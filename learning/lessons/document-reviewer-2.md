# Lessons — document-reviewer-2

Read this file before starting any task. Entry format is defined in `learning/README.md`.

Keep this file short and current: one lesson per recurring pattern, not one per incident. Lessons marked `promoted` have been written into `agents/document-reviewer-2.md` and stay here only as history.

---

## 2026-09-29 — Check every command's syntax, not only the code's logic
**Source**: downstream-catch
**Task**: Monitoring Kyverno policy violations with Wazuh (blog review + test, 2026-09-29)
**Reported by**: qa-agent
**What happened**: The independent technical check traced all 17 rules against the collector's code paths but didn't catch `kubectl create ns billing dev-apps payments`. `kubectl create namespace` takes exactly one NAME, so the first test fails. Reviewer 1 caught it. Reviewer 2's own tester claim assumed the command worked.
**Lesson**: In the independent technical check, check each shell command's arguments against its CLI usage (argument count, flag names, subcommand forms), not only the logic of the code blocks. Flag any command you can't confirm to the tester as a claim to verify.
**Status**: open

## 2026-09-29 — Judge headings from the HTML export, not the markdown export
**Source**: downstream-catch
**Task**: Monitoring Kyverno policy violations with Wazuh (blog review + test, 2026-09-29)
**Reported by**: qa-agent
**What happened**: N6 said the title and all sections were H1. The markdown export renders the Google Docs Title style as `#`. The HTML export shows correct Title > H1 > H2 > H3 nesting, which Reviewer 1 confirmed.
**Lesson**: Before you raise a heading-hierarchy or inline-formatting finding, confirm it in the HTML export. The markdown export flattens Title to H1 and drops code font and italics.
**Status**: promoted (2026-09-29, agents/document-reviewer-2.md "Ground truth")

## 2026-09-29 — Text visible in the published body is must-fix, and must-fixes mean "needs revision"
**Source**: downstream-catch
**Task**: Monitoring Kyverno policy violations with Wazuh (blog review + test, 2026-09-29)
**Reported by**: qa-agent
**What happened**: Doubled sentences left by two unaccepted suggestions were graded as a "wording nit" (S11), and the review returned "pass-with-fixes" while listing five must-fixes.
**Lesson**: Grade anything a reader would see in the published body (doubled text, broken commands, wrong output) as must-fix. If any must-fix is open, return "needs revision", not a pass.
**Status**: open

## 2026-09-29 — A prerequisite placed after the step that needs it goes to the tester as a claim
**Source**: downstream-catch
**Task**: Monitoring Kyverno policy violations with Wazuh (blog review + test, 2026-09-29)
**Reported by**: qa-agent (from a blogpost-tester finding)
**What happened**: The Kyverno RBAC step (S2) was flagged as belonging to the wrong section. The test showed that its position made the policies stay `READY=false` indefinitely, which blocked the post.
**Lesson**: When a step supplies something an earlier step needed, also list it under "Claims for the tester to verify".
**Status**: open
