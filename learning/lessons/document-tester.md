# Lessons — document-tester

Read this file before starting any task. Entry format is defined in `learning/README.md`.

Keep this file short and current: one lesson per recurring pattern, not one per incident. Lessons marked `promoted` have been written into `agents/document-tester.md` and stay here only as history.

---

## 2026-09-24 — Test a version-straddling doc on both versions at once
**Source**: user-feedback
**Task**: Monitoring Amazon Web Services v5.0 — all 11 tabs
**Reported by**: user
**What happened**: The test was reported per-tab against 5.0 only until the user said mid-run: "Your test should be a comparism of 4.x and 5.0 for each test in the listed tabs." The doc is titled v5.0 and links the 5.0-beta manual, but every use case cites 4.x numeric rule IDs. A single-version run cannot separate "the doc is wrong" from "the ruleset dropped this" — on 5.0 alone, Macie, WAF and S3-server-access all look identically broken, when in fact one is a missing decoder, one is a mis-parented decoder, and one is missing rules.
**Lesson**: When a doc's version label and its cited rule IDs disagree, deploy both versions and drive them from one shared data source, so every difference is attributable to the version. Report per-tab as a side-by-side, not as a single verdict with version caveats. Say so in the plan before starting, not after.
**Recurrence**: 2 (2026-10-01: the user asked for the 4.x vs 5.0 comparison up front, as "regression testing", for the RC1 rerun)
**Status**: open

## 2026-09-24 — Never report a ruleset gap from an empty findings index alone
**Source**: self-observed
**Task**: Monitoring Amazon Web Services v5.0 — GuardDuty and KMS tabs
**Reported by**: document-tester
**What happened**: `wazuh-findings-v5-cloud-services` held 0 documents after AWS events were ingested, which reads as "5.0 has no rules for this service". Replaying the same events through the content manager's `logtest` showed `rules_matched=1` for three KMS rules and 2 for GuardDuty. The findings pipeline was inert across every category on that build — 721 system-activity events also produced 0 findings.
**Lesson**: Before concluding a rule does not exist, prove it with `logtest` (`rules_evaluated` / `rules_matched`), and check whether *any* category is producing findings. If none is, report the pipeline as an environment-wide blocker separate from the doc's findings, and base detection verdicts on logtest.
**Status**: open

## 2026-09-24 — Run each documented snippet verbatim before running the corrected one
**Source**: self-observed
**Task**: Monitoring Amazon Web Services v5.0 — GuardDuty and ECR tabs
**Reported by**: document-tester
**What happened**: The GuardDuty tab's wodle block omits `<path>`; run as printed it collects nothing and exits **0**, with no error to troubleshoot. The ECR tab's block names a log group the tab's own prose contradicts; run as printed it raises `ResourceNotFoundException`. Both were only visible because the printed snippet was executed unmodified first.
**Lesson**: Execute every configuration snippet exactly as printed before fixing it, and record both outcomes. The gap between "as documented" and "as corrected" is the finding — a test that silently substitutes working values reports a passing tab.
**Status**: open

## 2026-09-24 — Resolve every cited rule ID against the shipped ruleset
**Source**: self-observed
**Task**: Monitoring Amazon Web Services v5.0 — Macie tab
**Reported by**: document-tester
**What happened**: The Macie tab cites rule IDs 80352 and 80354. A real Macie finding produced 80353. Grepping the shipped ruleset showed **80354 does not exist at all** — it would never have fired for anybody, and no amount of re-running the scenario would have revealed why.
**Lesson**: Extract every rule ID a doc cites and resolve each one against the ruleset on the host before testing the scenario. A cited ID that is absent is a finding on its own, independent of whether the use case reproduces. `agents/skills/document-tester/aws-service-tab-parity-test/resolve-rule-ids.sh` does this.
**Status**: open

## 2026-09-24 — Don't trust a doc's error-code table; read the source
**Source**: self-observed
**Task**: Monitoring Amazon Web Services v5.0 — troubleshooting section
**Reported by**: document-tester
**What happened**: Two exit codes hit during normal testing were documented wrongly. Code 16 is documented as a throttling error with "retry later" as the remedy; it is raised for any CloudWatch Logs `ClientError`, and the real cause was a missing IAM permission. Code 12 is documented as "invalid type of bucket"; it is the catch-all for every unhandled exception, and the real cause was an Inspector AccessDenied.
**Lesson**: When a documented error code appears during a test, grep the module source for that `sys.exit(N)` before quoting the doc's explanation. An error-code table that misdirects is a finding, and it is only catchable while you are holding the real failure.
**Status**: open

## 2026-09-24 — Check external links from a host with clean egress
**Source**: self-observed
**Task**: Monitoring Amazon Web Services v5.0 — link sweep
**Reported by**: document-tester
**What happened**: A sweep of 105 external URLs returned `000` for every single one, twice, which looked like a total outage. The URL list had been written by Windows Python and copied to Linux, so every entry carried a trailing `\r` and curl never resolved anything. After `sed -i 's/\r$//'`, five genuine failures surfaced — including both AWS reference links in the Inspector tab and an internal `documentation-dev.wazuh.com` link leaked into three tabs.
**Lesson**: A link sweep where *everything* fails is a harness bug, not a finding — strip `\r` and re-run before reporting. Always run the sweep from a host with unrestricted egress, and always include it: dead links to the vendor's own docs are among the cheapest real findings available.
**Status**: open

## 2026-10-01 — Sample events for another team: pair them on identical bytes
**Source**: self-observed
**Task**: Monitoring AWS v5.0 — RC1 regression run for external-devel-requests#6858
**Reported by**: document-tester
**What happened**: The first extraction picked "the first matching event" on each host separately, so a 4.x alert and a 5.0 event for the same gap were often two different records (a denied RunInstances on 4.x was an earlier `InvalidParameterValue`, not the permission denial). Re-running the 5.0 side keyed on the 4.x record's exact `event.original` bytes paired 43 of 45 gap events with the identical record.
**Lesson**: When a sample is meant to show "same input, different result", extract it on one version first and look the other version's copy up by its exact raw bytes. Never select independently per version with the same predicate. `aws-service-tab-parity-test/targets.py` does this.
**Status**: open
