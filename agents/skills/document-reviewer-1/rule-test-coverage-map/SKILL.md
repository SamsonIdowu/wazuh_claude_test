---
name: rule-test-coverage-map
description: For a post or doc that ships custom Wazuh rules, map every rule ID to the test step that claims it and to the screenshot that shows it, and flag rules with no test or no visual evidence. Use in any first-pass review of detection-engineering content.
owner: document-reviewer-1
created: 2026-09-29
last-verified: 2026-09-29
---

# Rule-to-test coverage map

## When to use
The piece includes a rules XML block and a Testing section with "This generates an alert for rule N"
claims. Readers paste every rule, so a rule nobody demonstrates is a claim nobody checked. Used on
the K8s CIS SCA and Kyverno policy-violation posts.

## Prerequisites
- The rules XML extracted to a file, and the doc's **plain-text** export (it keeps code newlines and
  heading lines). Headings and formatting are judged from the HTML export, not from this map.

## Steps
1. `python coverage-map.py rules.xml post-plain.txt --screenshot-ids <ids visible in the screenshot>`.
   Read the IDs off the screenshot yourself: the script can't see images.
2. The output is a table: rule → level → Testing subsection that names it → in screenshot?
   Base (level 0) rules are marked "never alerts".
3. For each `** NO TEST **` row, write a must-fix with a concrete trigger suggestion, or a "remove the
   rule" option.
4. For each claimed alert, check the rule's parent chain and field conditions against the data
   path the test actually produces. Two things to watch: a single action can produce both
   report-side and event-side alerts, and a `frequency` composite replaces the Nth parent alert.
   List mismatches as "Claims for the tester to verify".
5. Paste the table into the review. The report consolidator carries it into the author-facing report.

## Verification
On the Kyverno post, the script's output matched the hand-built map row for row: 17 rules, 11 claimed,
101912–101916 untested.

## Known failure modes
- Heading detection is heuristic: capitalized lines under 60 characters with no period or colon, and
  "Output"/"Note"/"Where" excluded. If a rule maps to an odd subsection, open the plain text at that
  line and check.
- A rule ID mentioned only in the "Where" list isn't counted as tested, because only the Testing
  section is scanned. That's intended.
