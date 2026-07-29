# Agent Information Directory

This directory contains information and guidance for AI agents running tests in this repository.

---

## Files

### AGENT_HANDOFF.md
**Complete onboarding guide for agents**

- 5-minute essentials (what to deploy, costs, timing)
- Key concepts (baseline, generated test infrastructure, cleanup)
- Step-by-step workflows with exact commands
- Common tasks (deploy, extend TTL, SSH, cleanup)
- Gap analysis (what's complete vs incomplete)
- Troubleshooting guide
- FAQ

**Start here if you're running tests.**

---

## For Agents Running Tests

### Quick Start

1. Read `AGENT_HANDOFF.md` (10 minutes)
2. Deploy baseline:
   ```bash
   cd terraform
   terraform apply -var="wazuh_version=4.14.6"
   ```
3. Follow test documentation from `test/` directory
4. Generate test-specific code in `test/terraform/` (only during test)
5. Cleanup:
   ```bash
   terraform destroy
   rm -rf test/terraform/
   ```

### Key Concepts

**Permanent (always in repo):**
- `terraform/` — Baseline Wazuh server + agent only
- `test/` — Test documentation and procedures
- All `.md` files — Guidance for testing

**Ephemeral (created during test, deleted after):**
- `test/terraform/` — Test-specific infrastructure code (agent generates)
- `results/` — Test outputs

**Result after cleanup:** Repository identical to baseline, no test artifacts.

---

## Repository Structure

```
(root)/
├── agent/ ← YOU ARE HERE
│   ├── README.md
│   └── AGENT_HANDOFF.md (start here)
│
├── terraform/ ← Baseline deployment
│   ├── main.tf (server + agent)
│   ├── variables.tf (core variables)
│   ├── wazuh-server-init.sh
│   ├── wazuh-agent-init.sh
│   └── terraform.tfvars
│
├── test/ ← Test documentation
│   ├── TEST_SCENARIOS_GUIDE.md
│   ├── DOCUMENTATION_TEST_TEMPLATE.md
│   ├── UPGRADE_TEST_TEMPLATE.md
│   ├── deployments/ (runbooks)
│   └── terraform/ (EMPTY - created during test)
│
├── ARCHITECTURE_CORRECTION.md (how system works)
└── README.md (project overview)
```

---

## Common Tasks

### Deploy Baseline
```bash
cd terraform
terraform apply -var="wazuh_version=4.14.6"
```

### SSH to Server
```bash
SERVER_DNS=$(cd terraform && terraform output -raw wazuh_server_public_dns)
ssh -i terraform/wazuh-test-key.pem ubuntu@$SERVER_DNS
```

### Get Dashboard Credentials
```bash
ssh -i terraform/wazuh-test-key.pem ubuntu@$SERVER_DNS \
  "sudo tar -xOf /root/wazuh-install-files.tar \
   wazuh-install-files/wazuh-passwords.txt"
```

### Extend TTL
```bash
# Edit terraform/terraform.tfvars:
# resource_ttl_minutes = 480  (8 hours instead of 4)

terraform apply
```

### Generate Test-Specific Code
During a test, create code in `test/terraform/`:

```bash
cat > test/terraform/generated-test.tf << 'EOF'
# Generated from: [Documentation URL]
# Purpose: [Test objective]

resource "aws_security_group_rule" "test_requirement" {
  # Generate infrastructure needed for this test
  ...
}
EOF

terraform apply
```

### Cleanup After Test
```bash
terraform destroy
rm -rf test/terraform/
rm -rf results/
# Repository is now baseline
```

---

## When Running Tests

1. **Read AGENT_HANDOFF.md** — Complete guide (10 min)
2. **Deploy infrastructure** — Based on test requirements
3. **Run tests** — Follow documentation in `test/`
4. **Generate code** — Only test-specific code in `test/terraform/`
5. **Document findings** — Save to `results/`
6. **Cleanup completely** — Delete test code, destroy infrastructure
7. **Verify baseline** — Repository should be unchanged

---

## Questions?

- **How do I deploy?** → See AGENT_HANDOFF.md
- **What's the architecture?** → Read ARCHITECTURE_CORRECTION.md
- **What are test scenarios?** → See test/TEST_SCENARIOS_GUIDE.md
- **How do I test documentation?** → See test/DOCUMENTATION_TEST_TEMPLATE.md
- **How do I test upgrades?** → See test/UPGRADE_TEST_TEMPLATE.md

---

**Last Updated**: Phase 1 Complete (2026-07-29)  
**Status**: Ready for agents to use
