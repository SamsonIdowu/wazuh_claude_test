# Agent Handoff: Wazuh Testing Infrastructure

**For**: Another AI agent picking up this repository
**Status**: Production ready
**Last Updated**: 2026-07-29

---

## TL;DR

This repo deploys an on-demand Wazuh instance (server + agent) on AWS, so you
can test a blog post, piece of documentation, or integration against a real
deployment instead of reading and guessing. It's cost-controlled (TTL-enforced
auto-termination) and self-contained (no secrets in the repo — AWS
credentials come from your local `~/.aws/credentials`).

**Read next, in this order:**
1. `agent/README.md` — quick reference for common commands
2. Root `README.md`'s "What This Is" section — how the baseline/ephemeral split works and why
3. `agent/TESTING_WORKFLOW.md` — how a document/blog post gets handed to you, and how to review it (functional + writing + structure/automation)
4. `test/TEST_SCENARIOS_GUIDE.md` — the R1-R4 verification rules and cost/scenario table

This file (`AGENT_HANDOFF.md`) is the essentials-and-troubleshooting
supplement to those four — it doesn't repeat their content.

---

## Before You Deploy Anything

```bash
aws sts get-caller-identity --profile wazuh   # do you have AWS access?
terraform --version                           # is Terraform installed?
cd terraform && terraform plan                # does a plan succeed?
```

If all three pass, you're ready.

---

## Deploy the Baseline (One Command)

```bash
cd terraform
terraform apply -var="wazuh_version=4.14.6"
```

That deploys the Wazuh server (manager + indexer + dashboard) and an agent —
nothing test-specific. See `terraform/variables.tf` for every variable this
accepts (`wazuh_version`, instance types, TTL, allowed CIDRs, etc.) — there is
no `test_scenario` or per-version-module variable; test-specific
infrastructure is generated into `test/terraform/` per test, not selected via
a variable. See the root `README.md`'s "What This Is" section for why.

| Component | Spec | Cost/hour |
|---|---|---|
| Wazuh server | t3.xlarge, Ubuntu 22.04 (manager+indexer+dashboard) | ~$0.1664 |
| Wazuh agent | t3.xlarge, Ubuntu 24.04 (also hosts TheHive on :9000) | ~$0.0832 |
| EBS volumes | gp3, encrypted | ~$0.10 |

Default TTL is 240 minutes and is **actually enforced** (a scheduled
`shutdown -h +N` plus `instance_initiated_shutdown_behavior = "terminate"` in
`main.tf`), not just a tag — extend it in `terraform.tfvars` if a test needs
longer.

---

## Verification Rules (Non-Negotiable)

Full detail in `test/TEST_SCENARIOS_GUIDE.md`; the short version:

- **R1**: Never report something as working from status text alone — verify
  with a command (`systemctl is-active ...`, `curl`, a database query).
- **R2**: Verify a URL returns HTTP 200 before piping it to a shell.
- **R3**: Review writing quality (grammar, formatting, consistency) alongside
  functional correctness — not as an afterthought.
- **R4**: Review document structure (heading hierarchy) and automation
  opportunities (can N manual steps become one script?) — and if a script is
  warranted, write it, don't just suggest it.

---

## Troubleshooting

| Problem | Check |
|---|---|
| `terraform init`/`apply` fails | `aws sts get-caller-identity --profile wazuh` |
| SSH times out | Instance may still be initializing (wait ~5 min) or your IP isn't in `allowed_ssh_cidrs` |
| Services not running | SSH in, `sudo systemctl status wazuh-manager wazuh-indexer wazuh-dashboard`, `sudo tail -100 /var/ossec/logs/ossec.log` |
| Dashboard unreachable | `sudo ss -tlnp \| grep 443`; get credentials via `sudo tar -xOf /root/wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt` |
| Running low on time | Edit `resource_ttl_minutes` in `terraform.tfvars`, re-`apply` — or `terraform destroy` if done |

---

## What NOT to Do

- Don't commit AWS credentials, or leave resources running without relying on TTL alone — `terraform destroy` when you're done, don't wait it out.
- Don't assume `terraform apply` exit code 0 means services are running — verify (R1).
- Don't leave test-specific scripts/files scattered anywhere at cleanup — `rm -rf test/terraform/ results/* test/requirements/*`, then sweep for stragglers created elsewhere. `git status --short` afterward should show nothing new at all.
- Don't try to run multiple tests simultaneously — they share the same key pair and security groups.

## What TO Do

- Verify with actual commands, always (R1-R2).
- Review writing quality and document structure, always (R3-R4) — write a script rather than just describing that one's possible.
- Check costs before deploying (`terraform output | grep -i cost`).
- `terraform destroy` when done, then confirm against AWS directly (`aws ec2 describe-instances`), not just the local Terraform state.
- Document findings clearly, in `results/`.

---

## FAQ

**Q: Why on-demand instead of a permanent test environment?**
A: Cost and cleanliness — a permanent environment accumulates drift and
test-specific leftovers. Ephemeral infra + a real cleanup step means every
test starts from the same known-good baseline.

**Q: What if a deployment fails partway through?**
A: TTL auto-terminates it regardless; `terraform destroy` cleans up
immediately without waiting.

**Q: Can I run two tests at once?**
A: Not recommended — they'd share the same security groups and key pair name.
Finish (or destroy) one before starting the next.

---

**Summary for another agent**: *"Deploy the baseline with `terraform apply
-var=\"wazuh_version=4.14.6\"` from `terraform/`. Read `agent/TESTING_WORKFLOW.md`
for how to receive and review whatever you're testing (functional + writing +
structure/automation). Verify everything with real commands, never trust
status text. Clean up completely — `terraform destroy`, verify against AWS,
remove test-specific scripts — when done."*
