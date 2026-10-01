---
name: custom-rule-alert-verification
description: Deploy a post's custom Wazuh 4.x rules file through the API, then prove each "this generates an alert for rule N" claim step by step with alert counts from alerts.json and an authenticated dashboard screenshot. Use for any blog post or doc that ships custom rules/decoders and claims specific alerts.
owner: blogpost-tester
created: 2026-09-29
last-verified: 2026-09-30
---

# Custom rule alert verification (Wazuh 4.x)

Built on the Kyverno policy-violations blog test (Wazuh 4.14.8, 17 rules, 11 claimed alerts).

## When to use
A post says "Add this rules file … This generates an alert for rule 1019xx." You need per-step
evidence (which alerts, how many, and in what order), not a final "it showed up in the dashboard".

## Prerequisites
- Baseline deployed (`terraform/`), agent enrolled and Active (`agent_control -l`).
- `wazuh-wui` API password from `wazuh-install-files/wazuh-passwords.txt` on the server.
- For screenshots: local Chrome + `npm install puppeteer-core` in a scratch dir. Port 443 open to your IP.

## Steps
1. Extract the rules XML from the doc (plain-text export keeps newlines) and parse it
   (`python -c "import xml.dom.minidom as m; m.parse('rules.xml')"`) before uploading.
2. `scp` it to the manager, then: `API_PW='…' sudo -E bash upload-rules.sh /tmp/<file>.xml`.
   That runs `PUT /rules/files/<name>`, the same endpoint the dashboard's **Save** button uses
   (in 4.14 the dashboard then offers a reload via `/manager/analysisd/reload`), then restarts the
   manager and lists the loaded IDs and levels. Check that the count equals the rules in the file.
3. Run `GROUP=<rule group> sudo -E bash newalerts.sh` once to set the marker. Then, after **each**
   test step, wait for the ingestion interval (for example one collector timer run) and call it again.
   The output is that step's alerts. Record them next to the post's claim.
4. For totals or a time window: `sudo python3 count-alerts.py <group|id-prefix> [12:48-13:08]` (UTC).
5. Screenshot the dashboard view the post describes:
   `WAZUH_DASH=https://<ip> WAZUH_CREDS=<passwords.txt> Q='rule.groups:<g> and not rule.id:<noise>' TFROM="'<iso>'" TTO="'<iso>'" node dashboard-capture.js events out`.
   The query is typed into the search bar (a `_q` URL param is ignored), and toasts are hidden before capture.
   `node dashboard-capture.js nav out` dumps the side-nav labels to verify a menu path.

## Verification
- Loaded-rule count from step 2 equals the rule count in the file.
- Dashboard hit count for the query equals `count-alerts.py` TOTAL for the same window. It did in
  the Kyverno test: 94 = 94, and 21 = 21 for the post's own window.

## Known failure modes
- **Child rules don't inherit the parent's groups.** A FIM child (`if_sid 550,553,554`) in a
  `<group name="custom,">` block loses `syscheck` and drops out of the FIM module. Check
  `rule.groups` on the real alert.
- **A `frequency="N"` composite replaces the Nth parent alert.** Five findings give four parent
  alerts and one composite, not five and one. (N was exact on 4.14.8.)
- **Count every alert a step produces, not just the claimed one.** Event and state double-reporting
  showed up only because each step's full output was listed.
- The dashboard shows browser-local time and `alerts.json` shows UTC. Label both in the report.
- Run time-travel simulations (back-dating a state file to test a 24h reminder rule) **last**. They
  contaminate later lifecycle checks such as recurrence.
