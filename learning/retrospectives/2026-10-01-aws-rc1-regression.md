# Retrospective — aws-rc1-regression — 2026-10-01

**Piece**: Monitoring Amazon Web Services v5.0 (Google Doc 11AMI7466Is1MpNWkfXj4AeLkysBhaEGJY4ATIi7r7z8), retested for wazuh/external-devel-requests#6858
**Objective from the brief**: Give the Threat Intel team sample events for every detection/parsing gap in #6858, retested on the 5.0.0 RC1 artifacts (nightly-backup 2026-10-01) and compared with 4.x as a regression test.
**Pipeline path taken**: Security Manager → Document Tester (audit-only path; no rewrite planned). Report published as an Artifact for the issue.
**QA verdict**: approved for hand-off. 45 gap events captured, 43 paired on identical raw bytes across versions; every #6858 gap reconfirmed on RC1 with a root cause. Not covered: Trusted Advisor (no Business support plan), success-path Stop/Start/EIP/CreateUser/CreateVpc events (permission classifier blocked creating them), Inspector-via-Security-Hub (never arrived).

## What each agent got right

- **document-tester**: one Terraform root for both hosts and every AWS source, so the whole stack destroyed in one call (57 resources) and the CLI-created remainder was verified by name. Boot-time enrolment plus root-only credential wrappers handled RC1's new random credentials without any secret appearing in a live command. ECR's "events sent, none indexed" was root-caused to `filter/DiscardedEvents` instead of being re-reported as a symptom.

## What a downstream agent had to catch

- Self-caught, late: per-version "first match" extraction produced mismatched records (a denied RunInstances on 4.x was a different error). Fixed by joining on exact `event.original` bytes. Lesson written.
- Self-caught: `tail` of the 4.x installer log printed that host's generated admin password into the session. Throwaway host, 443 restricted to the tester's /32, TTL-terminated; still a habit to drop. Recorded in the skill.

## User feedback on this task

- 2026-10-01 request (feedback-log): "compare 4x against 5.0 … More like Regression testing" and "Extract sample logs … for every test done and provide them in the report". Second recurrence of the 09-24 lesson that version-straddling AWS docs must be tested side by side; this time it was asked for up front. For document-tester: on any AWS-doc retest, plan the two-version run and the per-gap sample bundle from the start.

## Lessons written from this retrospective

- `learning/lessons/document-tester.md` — Sample events for another team: pair them on identical bytes (self-observed)
- `learning/lessons/document-tester.md` — "Test a version-straddling doc on both versions at once": recurrence 2 (user-feedback)
- `learning/lessons/shared.md` — In 5.0 a rule that matches on paper can still never fire (self-observed)

## Skill candidates

- Filed: `agents/skills/document-tester/aws-service-tab-parity-test/` extended with terraform-rc1/, collect-all.sh, targets.py, coverage.py, v4/v5-evidence.py, enable-integrations-rc1.sh, build-sample-bundle.py (see promoted-changelog 2026-10-01).

## Promotion candidates flagged to the Security Manager

- None at 3+ yet. The two-version lesson is at 2; one more AWS-doc request and it should become a standing instruction in `agents/document-tester.md`.
