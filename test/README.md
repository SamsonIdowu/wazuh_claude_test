# Test Documentation

## Files

- **AUTOMATED_TEST_TEMPLATE.md** — The template to fill in and run. Product-agnostic:
  works for any "deploy from a document, exercise it, report a verdict" test.
  Contains rules R1–R8 that Claude must follow during a run.
- **TTL_AND_AUTO_TERMINATION.md** — How self-termination actually works, and why
  the previous cosmetic implementation cost ~$4.92 in forgotten instances.

See also **`../DEPLOYMENT_RUNBOOK.md`** — the worked Wazuh + TheHive example, with
every failure encountered, its root cause, and the fix.

## Getting started

1. Edit `AUTOMATED_TEST_TEMPLATE.md` → set `DOCUMENT:` to your source document
2. Declare any external integrations needed (do **not** paste secrets — the file
   is version-controlled; supply them in chat)
3. Save
4. Tell Claude: **`execute test`**
5. Results land in `../results/`

## Other prompts

| Say | Effect |
|---|---|
| `execute test` | Run the full flow |
| `status` | Report verified state (re-checked, not recalled) |
| `cleanup test` | Destroy infrastructure and reset |
| `destroy now` | Immediate teardown |

## Test results

Written to `results/` at the repository root:

- `test-implementation-steps.md` — scenarios mapped to procedures
- `test-verdict.md` — PASS / FAIL / PARTIAL plus a per-step evidence table
- `execution-log.txt` — timeline, separating VERIFIED from UNVERIFIED
- `test-report.pdf` — printable report: general status, step-by-step status,
  failed steps, and recommendations (four tables)
- `deployment-outputs.md` — **sensitive, gitignored, deleted at teardown.**
  Every credential, DNS name, IP, and cert path the deployment produced. Not
  referenced from any of the files above, which are meant to be shared.

## Before trusting a result

A verdict is only as good as its evidence. `systemctl is-active` proves a process
runs, not that it works. `docker ps` showing `Up` proves a container started, not
that it serves traffic. `terraform apply` succeeding proves a VM exists, not that
provisioning finished.

Every claim in `test-verdict.md` should name the command that confirmed it, and
anything unchecked should say **UNVERIFIED**.

## Main documentation

See `README.md` at the repository root.
