# Wazuh Testing Infrastructure

On-demand infrastructure for testing Wazuh 4.14.6 and 5.0.0 with clean baseline and generated test-specific code.

---

## 📚 Quick Navigation

- **Agents starting a test**: Read `agent/AGENT_HANDOFF.md`
- **How the system works**: See "What This Is" below and `agent/TESTING_WORKFLOW.md`
- **Test documentation**: See `test/TEST_SCENARIOS_GUIDE.md`
- **Writing quality review (R3)**: Always check documents against `test/Language and formatting style guide for technical writing _ Wazuh.md`
- **Infrastructure code**: See `terraform/`

---

## 🎯 What This Is

**Clean baseline infrastructure** (always in repo):
- Wazuh server (Ubuntu 22.04, t3.xlarge)
- Wazuh agent (Ubuntu 24.04, t3.medium)
- Security groups, networking, TTL enforcement
- Works with Wazuh 4.14.6, 5.0.0, and other versions

**Test-specific code** (generated during tests, deleted after):
- Agents read documentation/blog posts
- Agents generate infrastructure code in `test/terraform/`
- Agents deploy, test, and document findings
- Cleanup deletes test code; repository reverts to baseline

---

## 🚀 For Agents Running Tests

### 1. Start Here
```bash
Read agent/AGENT_HANDOFF.md  (complete onboarding guide - 10 min)
```

### 2. Deploy Baseline
```bash
cd terraform
terraform apply -var="wazuh_version=4.14.6"
# Or 5.0.0, or any other version
```

### 3. Generate Test Code
During test, create test-specific infrastructure in `test/terraform/`:
```bash
cat > test/terraform/generated-test.tf << 'EOF'
# Generate from: [documentation/blog post analyzed by agent]
# Purpose: [test objective]

resource "aws_security_group_rule" "test_requirement" {
  # Infrastructure needed for this specific test
  ...
}
EOF
```

### 4. Deploy and Test
```bash
terraform apply  # Deploys with generated test code
# Run tests according to documentation
```

### 5. Cleanup Completely
```bash
terraform destroy           # Removes AWS resources
rm -rf test/terraform/      # Deletes test-specific code
rm -rf results/*            # Deletes test outputs (keep the .gitkeep)
rm -rf test/requirements/*  # Deletes reconstructed configs/policies from this test
# Verify against AWS directly, not just the exit code — terraform state can
# be empty while an orphaned resource still exists if something failed silently
```
Sweep for any other test-specific script you created outside these
directories too — `git status --short` afterward should show nothing new.

---

## 📁 Repository Structure

```
wazuh_test/
├── agent/
│   ├── AGENT_HANDOFF.md ← START HERE (agents)
│   └── README.md (quick reference)
│
├── terraform/ (BASELINE - always same)
│   ├── main.tf (Wazuh server + agent)
│   ├── variables.tf (core variables only)
│   ├── wazuh-server-init.sh (server setup)
│   ├── wazuh-agent-init.sh (agent setup)
│   ├── terraform.tfvars (your AWS config)
│   └── terraform.tfvars.example (template)
│
├── test/
│   ├── TEST_SCENARIOS_GUIDE.md (what tests are available)
│   ├── DOCUMENTATION_TEST_TEMPLATE.md (test docs framework)
│   ├── UPGRADE_TEST_TEMPLATE.md (upgrade testing)
│   ├── TTL_AND_AUTO_TERMINATION.md (cost control)
│   ├── Language and formatting style guide for technical writing _ Wazuh.md (R3 authority — writing quality review)
│   ├── deployments/
│   │   ├── wazuh_4_14_6/RUNBOOK.md (4.14.6 procedures)
│   │   ├── wazuh_5_0_0/RUNBOOK.md (5.0.0 procedures)
│   │   └── upgrade_4_to_5/RUNBOOK.md (upgrade procedures)
│   └── terraform/ (EMPTY - agents create during tests)
│
├── results/ (test outputs - gitignored, wiped at cleanup)
└── README.md (this file)
```

---

## 🏗️ Infrastructure Details

### Wazuh Server (Baseline)
- **OS**: Ubuntu 22.04 LTS
- **Instance**: t3.xlarge (4 vCPU, 16GB RAM)
- **Storage**: 30GB gp3 (encrypted)
- **Services**:
  - wazuh-manager
  - wazuh-indexer (with localhost binding fix)
  - wazuh-dashboard
- **Cost**: ~$0.17/hour

### Wazuh Agent (Baseline)
- **OS**: Ubuntu 24.04 LTS
- **Instance**: t3.medium (2 vCPU, 4GB RAM)
- **Storage**: 20GB gp3 (encrypted)
- **Services**:
  - wazuh-agent (auto-enrolled to server)
- **Cost**: ~$0.04/hour

### Security
- SSH restricted to `allowed_ssh_cidrs` (configure in terraform.tfvars)
- Agent communication VPC-private only (1514/1515)
- Dashboard public on HTTPS (443)
- API restricted to `allowed_api_cidrs`
- All volumes encrypted with AWS KMS
- IMDSv2 enforced on all instances

---

## ⏱️ Time-To-Live (TTL) & Cost Control

**Default**: 4 hours (240 minutes), auto-terminates

**Why it matters**: Instance automatically shuts down and TERMINATES (not stops), preventing orphaned EBS volumes and runaway costs.

### Extend TTL
```bash
# Edit terraform/terraform.tfvars:
resource_ttl_minutes = 480  # 8 hours

terraform apply
```

### Disable Auto-Termination
```bash
# Edit terraform/terraform.tfvars:
enable_auto_termination = false

terraform apply
```

### Cost Examples
- 45 min baseline deploy: ~$0.21
- 1 hour test: ~$0.21
- 2 hours testing: ~$0.42
- 4 hours (default TTL): ~$0.84

---

## 🔑 Core Variables

All in `terraform/variables.tf`:

| Variable | Type | Default | Purpose |
|----------|------|---------|---------|
| `aws_region` | string | us-east-1 | AWS deployment region |
| `aws_profile` | string | wazuh | AWS CLI profile name |
| `wazuh_version` | string | 4.14.6 | Wazuh version to deploy |
| `wazuh_server_instance_type` | string | t3.xlarge | Server instance type |
| `wazuh_server_volume_size` | number | 30 | Server volume (GB) |
| `agent_instance_type` | string | t3.medium | Agent instance type |
| `agent_volume_size` | number | 20 | Agent volume (GB) |
| `resource_ttl_minutes` | number | 240 | Auto-termination timeout |
| `enable_auto_termination` | bool | true | Enable TTL enforcement |
| `allowed_ssh_cidrs` | list | 0.0.0.0/0 | SSH access CIDR blocks |
| `allowed_api_cidrs` | list | 0.0.0.0/0 | API access CIDR blocks |

---

## 🧹 Cleanup

After each test:

```bash
# Step 1: Destroy AWS resources
cd terraform
terraform destroy

# Step 2: Delete test-specific code (sweep for stragglers outside this dir too)
rm -rf test/terraform/

# Step 3: Delete test outputs and reconstructed requirements
rm -rf results/*            # keep the .gitkeep
rm -rf test/requirements/*

# Step 4: Verify against AWS directly, not just the exit code — terraform
# state can be empty while an orphaned resource still exists if something
# failed silently
aws ec2 describe-instances --profile wazuh \
  --filters "Name=tag:Name,Values=wazuh-server,wazuh-agent" \
  --query "Reservations[].Instances[].State.Name"

# Result: Repository identical to baseline
```

---

## 🐛 Troubleshooting

### SSH Connection Fails
```bash
# Verify key file exists and has right permissions
ls -la terraform/wazuh-test-key.pem
# Should be: -rw------- (600)

# Get server DNS from Terraform
cd terraform
terraform output -raw wazuh_server_public_dns
```

### Services Not Running
```bash
# SSH to server
ssh -i terraform/wazuh-test-key.pem ubuntu@<server_dns>

# Check status
sudo systemctl status wazuh-manager
sudo systemctl status wazuh-indexer
sudo systemctl status wazuh-dashboard

# View logs
sudo tail -100 /var/ossec/logs/ossec.log
```

### Dashboard Not Accessible
```bash
# Verify service running
sudo systemctl status wazuh-dashboard

# Verify port listening
sudo ss -tlnp | grep 443

# Get credentials
sudo tar -xOf /root/wazuh-install-files.tar \
  wazuh-install-files/wazuh-passwords.txt
```

### Terraform Issues
```bash
# Validate configuration
cd terraform
terraform validate

# Check state
terraform state list

# Refresh state
terraform refresh
```

---

## 📖 Documentation

### For Infrastructure Setup
- This file's "What This Is" and "Cleanup" sections — system design and cleanup procedures
- `terraform/variables.tf` — All configuration options with descriptions

### For Testing
- `agent/AGENT_HANDOFF.md` — Complete agent onboarding (START HERE)
- `test/TEST_SCENARIOS_GUIDE.md` — Available test scenarios
- `test/DOCUMENTATION_TEST_TEMPLATE.md` — Framework for testing docs
- `test/UPGRADE_TEST_TEMPLATE.md` — Framework for upgrade testing
- `test/TTL_AND_AUTO_TERMINATION.md` — Cost control details
- `test/deployments/*/RUNBOOK.md` — Version-specific procedures
- `test/deployments/wazuh_5_0_0/artifact_urls_5.0.0-latest.yaml` — **Preferred source for any 5.0/5.0-beta package or installer URL.** Check this before hardcoding a version string (e.g. `5.0.0-beta4`) into an install command — a guessed version string can resolve to a working installer script that installs a *different* package version than the one named, which only surfaces as a failure at install time.
- `test/Language and formatting style guide for technical writing _ Wazuh.md` — Authoritative Wazuh writing style guide; every document review (R3) is checked against this file

---

## 🔗 References

- **Wazuh Docs**: https://docs.wazuh.com/
- **Terraform AWS**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **EndOfLife.date**: https://endoflife.date/ (for version info)

---

**Last Updated**: 2026-07-29  
**Architecture**: Clean baseline + generated test code  
**Status**: Production ready for agent testing

For agents: Start with `agent/AGENT_HANDOFF.md`
