# Automated Test Template

Fill in the **Configuration** section, save, then tell Claude: **`execute test`**

This template is product-agnostic. It works for any test that follows the shape
*"stand up infrastructure from a document, exercise it, report a verdict"* —
Wazuh, Shuffle, TheHive, or anything else described in a source document.

---

## Configuration — fill this in

### 1. Source document (required)

```
DOCUMENT: https://docs.google.com/document/d/PASTE_ID_HERE/edit
```

Google Docs, a URL, or a local path. Must be readable by Claude.

### 2. Test scope (optional — defaults to everything the document describes)

```
IN SCOPE:     all scenarios described in the document
OUT OF SCOPE:
```

### 3. Infrastructure overrides (optional — otherwise derived from the document)

```
REGION:       us-east-1
TTL_MINUTES:  240
```

### 4. External integrations (required only if the document uses them)

Do **not** paste secrets into this file — it is version-controlled. Provide them
in chat, or export them as environment variables. Just declare which are needed:

```
INTEGRATIONS NEEDED:  [ ] Slack   [ ] Shuffle   [ ] TheHive   [ ] Jira   [ ] other: ______
PROVISION ON AWS:     [ ] TheHive (Terraform can deploy it)
```

### 5. Teardown policy

```
ON COMPLETION:  [x] destroy immediately   [ ] keep until I say so
```

---

## Rules Claude must follow

These are derived from a real run where ignoring them cost hours and money.
They are not stylistic preferences.

### R1 — Never report success without a command confirming it

State the evidence alongside every claim. Specifically:

| Don't trust | Because | Check instead |
|---|---|---|
| `systemctl is-active` | Process can run while broken. A Wazuh agent shows `active` while never enrolling. | The functional endpoint (`agent_control -l`) |
| `docker ps` = `Up` | Container started ≠ app serving | `curl` the app's status endpoint |
| `terraform apply` success | Means the VM exists, not that provisioning finished | `cloud-init status` + a marker file |
| A tag or a doc | Metadata is not behaviour | Find the code that enforces it |
| Elapsed time | Slow ≠ progressing, and ≠ dead | Read a log; check the process |

If a check has not been run, write **UNVERIFIED**. Never write ✅ or PASS
speculatively — a false PASS sends debugging at the wrong component and wastes
the whole session.

### R2 — Verify a URL before piping it to a shell

```bash
curl -s -o /dev/null -w '%{http_code}' "$URL"   # must be 200
```

A 403 or 404 piped to `bash` fails **silently** and looks like a clean install.

### R3 — Write install scripts that fail loudly

```bash
set -euxo pipefail
exec > >(tee -a /var/log/<component>-install.log) 2>&1
# ... work ...
echo "READY=$(date -Is)" > /root/<COMPONENT>_READY   # poll for this, don't guess
```

Add a readiness gate that polls the real endpoint and `exit 1`s on timeout.
Never conclude "it should be up by now."

### R4 — Editing `user_data` does not re-provision an instance

`cloud-init` runs user-data only on **first boot**. `terraform apply` after an
edit resizes in place, keeps the **same instance ID**, and reports success while
the corrected script never runs.

```bash
terraform apply -replace=aws_instance.<name> -target=aws_instance.<name>
```

Confirm the **instance ID changed**. Each replacement also assigns a new public IP.

### R5 — Prefer the vendor's official installer and compose files

Hand-rolled installs cost this project two full redeploys. Use the vendor
quickstart script or clone their compose repo, and pin versions. When adapting a
vendor script for unattended use, check for interactive prompts —
`grep -n 'read -p' <script>` — because there is often more than one.

### R6 — Confirm teardown against the cloud provider, not the tool

```bash
aws ec2 describe-instances --filters "Name=tag:Name,Values=..." \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' --output table
aws ec2 describe-volumes --filters "Name=status,Values=available"   # orphans bill
```

### R7 — Never commit secrets

Tokens go in chat or env vars, never into a results file. `.gitignore` blocks
common credential filenames, but do not rely on it.

### R8 — Ask before spending or exposing

Confirm first when about to: exceed the declared TTL, resize up, open a port to
`0.0.0.0/0`, or destroy anything. State the cost or exposure in the question.

---

## Execution phases

### Phase 1 — Read the document
Extract: components and versions, infrastructure requirements, the test
scenarios, expected outcomes, and any required external integrations.

Then **restate the plan and the estimated cost, and confirm before spending.**

### Phase 2 — Plan
Write `results/test-implementation-steps.md`: infrastructure to be deployed, each
document scenario mapped to a concrete procedure, and the pass criteria.

Generate `terraform/terraform.tfvars` from the document's requirements.

### Phase 3 — Deploy
`terraform init && terraform validate && terraform apply`

Then **wait on a marker file** (per R3), not a guessed duration. Verify
`cloud-init status` is `done`, not `error`.

Immediately after apply, write every `terraform output` (DNS names, IPs,
generated key paths) to `results/deployment-outputs.md` (see box below). Do not
let these values live only in chat or in Terraform state.

### Phase 4 — Verify the platform *before* testing it

Do not run scenarios against an unverified platform. Build a table:

| Check | Command | Result |
|---|---|---|
| services active | `systemctl is-active <svc>` | |
| UI serving | `curl -k -o /dev/null -w '%{http_code}'` | |
| API authenticating | real auth call returning a token | |
| agent/client registered | the functional check, not the process check | |
| credentials valid | one live API call per integration | |

Test every supplied credential here. Discovering a bad token mid-run wastes the
window.

As credentials are generated or retrieved (a vendor installer's random admin
password, an API key created for the test, a cert fingerprint), append them to
`results/deployment-outputs.md` — never into `test-verdict.md` or
`execution-log.txt`, which are meant to be shareable.

---

#### `results/deployment-outputs.md` — all deployment outputs, one file

Every credential, DNS name, IP address, and cert path the deployment produces
goes in exactly one file, so nothing sensitive is scattered across chat,
`execution-log.txt`, or the verdict:

```markdown
# Deployment Outputs — SENSITIVE, not committed, deleted after this test

## Infrastructure
- <component>: <public DNS> / <public IP> / <private IP>
- SSH: `ssh -i <generated-key>.pem ubuntu@<dns>`

## Credentials (as generated/retrieved — never guess or reuse an example value)
- <component> dashboard: <URL> — <user> / <password>
- <component> API key: <key>

## Certificates
- <path or fingerprint, if the deployment generates one>

## External integrations supplied for this test
- <service>: <endpoint> — <token, if the user provided one for this run>
```

This file:
- **Must never appear in `test-verdict.md`, `execution-log.txt`, or the PDF
  report** — those are written to be shared; this one is not.
- **Must be covered by `.gitignore`** before it is ever written.
- **Must be deleted at Phase 7 (Teardown)**, every time, regardless of whether
  the test passed or failed. Confirm the deletion (R1) — don't assume `rm`
  succeeded.

### Phase 5 — Execute scenarios
Run each scenario from the document, then **confirm the effect** — query for the
data, don't assume the trigger worked.

### Phase 6 — Report

Write `results/test-verdict.md` with a per-step evidence table, and
`results/execution-log.txt` separating VERIFIED from UNVERIFIED.

Record every defect: symptom → root cause → fix. Distinguish defects in the
*subject under test* from defects in *this repo's own config*.

#### Then generate `results/test-report.pdf`

A self-contained PDF containing **four tables, in this order**:

**Table 1 — General status** (one row, the summary)

| Field | Value |
|---|---|
| Verdict | PASS / FAIL / PARTIAL |
| Steps passed | e.g. 8/8 |
| Document under test | title + link |
| Components & versions | e.g. Wazuh 4.14.6, TheHive 5.7.3 |
| Started / finished / duration | |
| Infrastructure | instance types and count |
| Cost | accrued $ |
| Teardown | destroyed + verified / still running |

**Table 2 — Step-by-step status** (one row per step; the core of the report)

| # | Phase | Step | Command / method | Expected | Actual | Status |
|---|---|---|---|---|---|---|

`Status` ∈ PASS / FAIL / SKIPPED / **UNVERIFIED**. Every PASS must name the
command in `Actual` that proves it (per R1). Include steps that were skipped and
why — a silently omitted step reads as coverage that does not exist.

**Table 3 — Failed steps** (omit the table only if genuinely zero failures)

| # | Step | Symptom / error | Root cause | Fix applied | Resolved |
|---|---|---|---|---|---|

Quote the actual error text, not a paraphrase. State whether the defect was in
the subject under test or in this repo's own configuration — they have different
audiences.

**Table 4 — Recommendations**

| # | Priority | Area | Recommendation | Rationale |
|---|---|---|---|---|

Priority ∈ HIGH / MEDIUM / LOW. Cover at minimum: unresolved failures, security
exposure created during the test (open ports, plaintext credentials), cost or TTL
risks, and any limitation that weakens the verdict.

**Generation.** Write `results/test-report.html` first — self-contained, with a
print stylesheet and **no external assets** (inline the CSS; remote fonts or
stylesheets will not load during conversion).

Primary method: **headless Chrome or Edge.** Verified working on this machine;
`wkhtmltopdf`, `pandoc`, `weasyprint` and `reportlab` were all confirmed *absent*,
so do not reach for them first.

```bash
CHROME="/c/Program Files/Google/Chrome/Application/chrome.exe"
# fallback: "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"

"$CHROME" --headless --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="$(cygpath -w "$PWD/results/test-report.pdf")" \
  "$(cygpath -w "$PWD/results/test-report.html")"
```

`cygpath -w` matters — the browser needs Windows paths, and a POSIX path fails
silently with no PDF written.

If no browser is present, install a converter on demand (`pip install weasyprint`).

Then **verify the artifact** rather than assuming (R1):

```bash
ls -l results/test-report.pdf && file results/test-report.pdf
# expect: non-trivial size and "PDF document, version N, M page(s)"
```

A zero-byte or missing file means the conversion failed regardless of the exit
code. If every method fails, say so plainly, keep the HTML, and report the PDF as
**not generated** — never claim a PDF exists without the `file` check.

Never fabricate table contents. If a value was not measured, write UNVERIFIED.

### Phase 7 — Teardown
Follow the declared policy. Destroy, then verify per R6 (against the cloud
provider, not the exit code) and report the final cost.

Then, unconditionally:

```bash
rm -f results/deployment-outputs.md
ls results/deployment-outputs.md 2>&1   # must report "No such file" — confirm, don't assume
```

Do this whether the test passed or failed, and whether the user asked for
cleanup or not — a results directory left holding live credentials after the
infrastructure is gone is a real exposure, not a formality.

---

## Deliverables

```
results/
├── test-implementation-steps.md   scenarios mapped to procedures
├── test-verdict.md                PASS / FAIL / PARTIAL + evidence table
├── execution-log.txt              timeline, VERIFIED vs UNVERIFIED
├── test-report.html               printable source for the PDF
├── test-report.pdf                4 tables: general status, step-by-step,
│                                  failed steps, recommendations
└── deployment-outputs.md          credentials/DNS/IP/certs — SENSITIVE,
                                   gitignored, deleted at Phase 7, every time
```

Reusable procedures and gotchas go in `DEPLOYMENT_RUNBOOK.md` at the repo root —
so the next run does not rediscover them.

---

## Other prompts

| Say | Effect |
|---|---|
| `execute test` | Run the full flow above |
| `status` | Report verified state; re-check rather than recall |
| `cleanup test` | Destroy infrastructure and reset for a fresh run |
| `destroy now` | Immediate teardown |

---

## Adapting this to a new product

1. Replace the Terraform in `terraform/` with what your product needs, keeping
   the TTL wiring (`local.ttl_prologue` + `instance_initiated_shutdown_behavior`).
2. Point `DOCUMENT` at your source document.
3. Note the product's verification commands in Phase 4 — the *functional* check
   for each component, not the process check.
4. Keep R1–R8 unchanged. They are product-independent.

See `DEPLOYMENT_RUNBOOK.md` for a worked example (Wazuh + TheHive), including
each failure encountered and how it was resolved.
