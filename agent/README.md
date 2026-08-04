# Agent Information Directory

This directory contains information and guidance for AI agents running tests in this repository.

---

## Files

### AGENT_HANDOFF.md
**Essentials-and-troubleshooting supplement** — read the root `README.md`'s
"What This Is" section and `agent/TESTING_WORKFLOW.md` first; this file
doesn't repeat their content.

- 5-minute essentials (what to deploy, costs, timing)
- Verification rules summary (R1-R4)
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

**Ephemeral, deleted at cleanup — every test, no exceptions:**
- `test/terraform/` — Test-specific infrastructure code (agent generates)
- `results/` — the test report and any scripts written as findings
- `test/requirements/` — reconstructed configs/policies the test needed
- Any other test-specific script created outside those directories — sweep for these too

**Result after cleanup:** AWS resources gone, all test-specific artifacts
gone, repository identical to its starting state.

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
│   ├── Language and formatting style guide for technical writing _ Wazuh.md (R3 authority)
│   ├── deployments/ (runbooks)
│   └── terraform/ (EMPTY - created during test)
│
└── README.md (project overview — see "What This Is" for how the system works)
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
rm -rf results/*            # keep the .gitkeep
rm -rf test/requirements/*
```
Sweep for any other test-specific script created outside these directories
too — `git status --short` afterward should show nothing new.

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
- **What's the architecture?** → Read the root README.md's "What This Is" section
- **What are test scenarios?** → See test/TEST_SCENARIOS_GUIDE.md
- **How do I test documentation?** → See test/DOCUMENTATION_TEST_TEMPLATE.md
- **How do I test upgrades?** → See test/UPGRADE_TEST_TEMPLATE.md
- **How do I review writing quality (R3)?** → Check the document against
  `test/Language and formatting style guide for technical writing _ Wazuh.md`
  — the authoritative Wazuh style guide, not a generic grammar checklist

---

**Last Updated**: Phase 1 Complete (2026-07-29)  
**Status**: Ready for agents to use
