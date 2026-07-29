# Wazuh 4.14.6 EOL Detection Testing Infrastructure

Comprehensive infrastructure for testing Wazuh 4.14.6 EOL detection capabilities with automated testing framework.

---

## 📚 Table of Contents

1. [Quick Start](#quick-start)
2. [Project Structure](#project-structure)
3. [Automated Testing](#automated-testing)
4. [Manual Deployment](#manual-deployment)
5. [Infrastructure Details](#infrastructure-details)
6. [Managing Resources](#managing-resources)
7. [Test Results](#test-results)
8. [Cleanup & Fresh Start](#cleanup--fresh-start)
9. [Troubleshooting](#troubleshooting)

---

## 📋 Version Support Matrix

| Version | Status | Fresh Deploy | EOL Detection | TheHive | Upgrade Path | Notes |
|---------|--------|--------------|---------------|---------|--------------|-------|
| **4.14.6** | ✅ Production | ✅ Done | ✅ Done | ✅ Done | — | Blog post tested, full runbook available |
| **5.0.0** | 🔄 In Progress | 📋 Phase 2 | 📋 Phase 3 | 📋 Phase 3 | 📋 Phase 4 | Research in progress, stub runbook created |
| **5.1.0** | 🔴 Planned | 🔴 Future | 🔴 Future | 🔴 Future | 🔴 Future | Available after 5.0.0 validation |

**Status Legend:**
- ✅ Done — Tested and verified working
- 🔄 In Progress — Active development/research
- 📋 Planned — Designed, waiting for prerequisites
- 🔴 Future — Not yet started, depends on earlier phases

---

## 🚀 Quick Start

### Option 1: Automated Testing (Recommended)

1. Edit `test/AUTOMATED_TEST_TEMPLATE.md`
2. Add your Google Drive document link in the Configuration section
3. Save the file
4. Message Claude: **"execute test"**
5. Wait 20-40 minutes
6. Check `results/` folder for test outputs

### Option 2: Manual Deployment

1. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars`
2. Edit with your AWS credentials and IP address
3. Run `cd terraform && terraform init && terraform apply`
4. SSH to instances and manually run tests
5. Document results in `results/` folder

---

## 📁 Project Structure

```
wazuh_test/
├── README.md                           (This file - main documentation)
├── cleanup.ps1 / cleanup.sh           (Cleanup scripts)
├── .gitignore / .gitattributes        (Git configuration)
├── terraform/
│   ├── main.tf                        (EC2, security groups, networking)
│   ├── variables.tf                   (Configurable parameters)
│   ├── outputs.tf                     (Connection details)
│   ├── thehive.tf                     (TheHive EC2 + security group)
│   ├── thehive-init.sh                (TheHive install via StrangeBee compose)
│   ├── wazuh-agent-init.sh           (Agent installation)
│   ├── terraform.tfvars.example       (Config template - copy this)
│   └── terraform.tfvars               (Your config - create from example)
├── test/
│   ├── AUTOMATED_TEST_TEMPLATE.md    (Fill in + say "execute test")
│   ├── README.md                     (Test documentation index)
│   └── TTL_AND_AUTO_TERMINATION.md   (TTL management guide)
├── DEPLOYMENT_RUNBOOK.md              (What works: procedures + gotchas)
└── results/                           (Test outputs - auto-generated)
    ├── test-implementation-steps.md
    ├── test-verdict.md
    ├── execution-log.txt
    ├── test-report.html / .pdf
    └── deployment-outputs.md          (credentials/DNS/IP/certs - gitignored,
                                        deleted by cleanup, never committed)
```

---

## 🤖 Automated Testing

The automated test system dynamically adapts infrastructure to match your document requirements while keeping test procedures constant.

### How It Works: 6 Automated Phases

**Phase 1: Document Analysis (5 min)**
- Reads your Google Drive document
- Extracts infrastructure requirements (instance types, OS, versions, storage)
- Identifies test implementation steps

**Phase 2: Test Planning & Infrastructure Analysis (10 min)**
- Generates `terraform/terraform.tfvars` from document requirements
- Creates `results/test-implementation-steps.md` with test procedures
- Plans resource configuration

**Phase 3: Infrastructure Setup (10 min)**
- Executes `terraform init && terraform plan && terraform apply`
- Waits 5-10 minutes for services to initialize

**Phase 4: Test Execution (10-15 min)**
- SSH to Wazuh server
- Deploys configurations from document
- Executes test steps sequentially
- Captures all outputs

**Phase 5: Results & Verdict (5 min)**
- Creates `results/test-verdict.md` (PASS/FAIL/PARTIAL, with a per-step evidence table)
- Generates `results/execution-log.txt` (timeline, VERIFIED vs UNVERIFIED)
- Generates `results/test-report.pdf` (general status, step-by-step, failed steps, recommendations)

**Phase 6: Cleanup (auto-managed)**
- Auto-terminates after 4 hours (default), genuinely enforced
- Or extend TTL in `terraform/terraform.tfvars`
- Or manual `terraform destroy`

### Timeline Example

```
10:00 AM - Update test/AUTOMATED_TEST_TEMPLATE.md, say "execute test"
10:05 AM - Claude reads document, extracts requirements
10:10 AM - Infrastructure analysis and terraform generation
10:15 AM - Terraform deployment begins
10:25 AM - Services ready, test execution starts
10:40 AM - Tests complete
10:45 AM - Results available in results/ folder
```

### Key Architecture: Variable Infrastructure, Constant Tests

- **Infrastructure** (instance types, OS, versions, storage) adapts to your document requirements
- **Test procedures** (SSH commands, service checks, test flow) remain standardized
- **Results** clearly show what was deployed and tested

This design allows testing any Wazuh configuration without modifying test procedures.

### How to Use Automated Testing

**Step 1: Update Template**
```bash
# Edit test/AUTOMATED_TEST_TEMPLATE.md
# Add your Google Drive document link in the Configuration section
# Save the file
```

**Step 2: Execute**
```
Message Claude: "execute test"
```

**Step 3: View Results** (after 20-40 minutes)
```bash
cat results/test-verdict.md        # Pass/Fail summary + evidence table
open results/test-report.pdf       # General status, step-by-step, failures, recommendations
cat results/execution-log.txt      # Timeline
```

---

## 📝 Manual Deployment & Testing

### Prerequisites

- AWS account with credentials configured locally
- Terraform installed (v1.0+)
- SSH client
- Your public IP address (for security group configuration)

### Step 1: Create Terraform Configuration

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform/terraform.tfvars`:

```hcl
aws_region                  = "us-east-1"
aws_profile                = "wazuh"     # named profile in ~/.aws/credentials
wazuh_version              = "4.14.6"
wazuh_server_instance_type = "t3.xlarge"
agent_instance_type        = "t3.medium"
allowed_ssh_cidrs          = ["YOUR_IP/32"]
allowed_api_cidrs          = ["YOUR_IP/32"]
resource_ttl_minutes       = 240         # 4 hour default
enable_auto_termination    = true        # Auto-cleanup enabled
```

### Step 2: Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Terraform outputs:
- Wazuh server public DNS
- Wazuh agent public DNS
- SSH key path (`wazuh-test-key.pem`)
- Dashboard URL
- TTL countdown

### Step 3: Access Resources

**SSH to Wazuh Server:**
```bash
ssh -i wazuh-test-key.pem ubuntu@<server_public_dns>
```

**Access Wazuh Dashboard:**

The quickstart installer generates a random admin password per deployment — it
is never `admin/admin`. During an automated run, the dashboard URL and
credentials are written to `results/deployment-outputs.md` (gitignored,
deleted by cleanup). For a manual deployment, retrieve the password directly:

```bash
ssh -i wazuh-test-key.pem ubuntu@<server_public_dns> \
  "sudo tar -xOf /root/wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt"
```

**SSH to Agent:**
```bash
ssh -i wazuh-test-key.pem ubuntu@<agent_public_dns>
```

### Step 4: Verify Services

```bash
# SSH to server first, then:
sudo systemctl status wazuh-manager
sudo systemctl status wazuh-dashboard
sudo systemctl status wazuh-indexer

# View logs if needed:
sudo tail -50 /var/ossec/logs/ossec.log
```

### Step 5: Run Tests

Follow the procedures in `test/AUTOMATED_TEST_TEMPLATE.md` (Phases 4–5): verify
the platform, execute each scenario from your source document, and confirm the
effect rather than assuming the trigger worked.

### Step 6: Document Results

Create test result files in `results/`:
- `test-implementation-steps.md` — What you tested
- `test-verdict.md` — PASS/FAIL/PARTIAL summary with a per-step evidence table
- `test-report.pdf` — General status, step-by-step status, failed steps, recommendations

---

## 🏗️ Infrastructure Details

### Wazuh Server (Ubuntu 22.04)

- **Instance Type:** `t3.xlarge` (customizable)
- **Root Volume:** 30 GB (gp3, encrypted)
- **Services:**
  - Wazuh Manager 4.14.6
  - Wazuh Dashboard 4.14.6
  - Wazuh Indexer 4.14.6
- **Cost:** ~$0.17/hour
- **Security Group Ports:**
  - SSH (22) — from your IP
  - Dashboard (443) — from anywhere
  - API (55000) — from your IP
  - Agent comms (1514) — from anywhere

### Wazuh Agent (Ubuntu 24.04)

- **Instance Type:** `t3.medium` (customizable)
- **Root Volume:** 20 GB (gp3, encrypted)
- **Services:**
  - Wazuh Agent 4.14.6 (auto-enrolled to server)
- **Cost:** ~$0.04/hour
- **Security Group Ports:**
  - SSH (22) — from your IP
  - Agent comms (1514) — from Wazuh server only

### Single Version Control

Change Wazuh version for all components with one variable:

```hcl
wazuh_version = "4.14.6"  # Updates Manager, Dashboard, Indexer, Agent
```

### Security Features

- **Encrypted volumes:** Root volumes use gp3 with encryption enabled
- **IMDSv2 enforced:** Instance metadata requires secure tokens
- **Restricted SSH:** SSH access limited to your IP by default
- **Public dashboard:** Dashboard accessible from internet (manager is not)
- **Security groups:** Restrictive ingress rules, unrestricted egress

---

## ⏱️ Managing Resources

### TTL (Time-To-Live)

**Default:** 4 hours with auto-termination, genuinely enforced (see
`test/TTL_AND_AUTO_TERMINATION.md`) — not just a tag or a doc claim.

### Extend TTL

Edit `terraform/terraform.tfvars`:
```hcl
resource_ttl_minutes = 120  # 2 hours
```

Then apply:
```bash
cd terraform
terraform apply
```

### Disable Auto-Termination

Edit `terraform/terraform.tfvars`:
```hcl
enable_auto_termination = false
```

Then apply:
```bash
cd terraform
terraform apply
```

### Manually Cleanup

Immediately terminate resources:
```bash
cd terraform
terraform destroy
```

### Cost Estimates

| Duration | Test Cost |
|----------|-----------|
| 1 hour | ~$0.21 |
| 2 hours | ~$0.42 |
| 4 hours | ~$0.84 |
| 8 hours | ~$1.68 |
| 24 hours | ~$5.04 |

---

## 📊 Test Results

Test results are stored in the `results/` directory with these files:

**test-implementation-steps.md**
- What was tested
- Infrastructure used
- Configuration changes made
- Source document scenarios mapped to test procedures

**test-verdict.md**
- Overall result: PASS / FAIL / PARTIAL
- Summary of findings
- Recommendations for next steps

**test-report.pdf**
- General status table (verdict, steps passed, duration, cost, teardown state)
- Step-by-step status table (command / expected / actual / status)
- Failed steps table (symptom, root cause, fix, resolved)
- Recommendations table (priority, area, recommendation, rationale)

**execution-log.txt**
- Timeline of all events
- Phase completion times
- Service status at each step

**deployment-outputs.md** *(sensitive — gitignored, deleted by cleanup)*
- Every credential, DNS name, IP address, and cert path produced by the
  deployment: dashboard/API URLs, generated passwords, SSH connection strings,
  and any external integration credentials supplied for the test
- Never referenced from `test-verdict.md` or committed anywhere — it exists
  only so a human doesn't have to hunt through chat history or `terraform
  output` for connection details during the test window

---

## 🔧 Configuration Reference

### Required Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `aws_region` | string | us-east-1 | AWS region for deployment |
| `aws_profile` | string | wazuh | Named AWS CLI profile from `~/.aws/credentials` |
| `wazuh_version` | string | 4.14.6 | Wazuh version (all components) |

### Instance Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `wazuh_server_instance_type` | string | t3.xlarge | Server instance type |
| `wazuh_server_volume_size` | number | 30 | Server root volume (GB) |
| `agent_instance_type` | string | t3.medium | Agent instance type |
| `agent_volume_size` | number | 20 | Agent root volume (GB) |

### Security Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `allowed_ssh_cidrs` | list | 0.0.0.0/0 | CIDR blocks for SSH access |
| `allowed_api_cidrs` | list | 0.0.0.0/0 | CIDR blocks for API access |

### TTL Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `resource_ttl_minutes` | number | 240 | Auto-termination timeout (1-1440 minutes) |
| `enable_auto_termination` | bool | true | Enable automatic resource cleanup |

---

## 🧹 Cleanup & Fresh Start

To clean up from a previous test and prepare for a new one:

### Option 1: Use Cleanup Script (Recommended)

**Windows (PowerShell):**
```powershell
.\cleanup.ps1
```

**Linux/Mac (Bash):**
```bash
bash cleanup.sh
```

The script will:
- Destroy all AWS infrastructure
- Remove previous test results
- Reset terraform configuration
- Clear terraform cache and state files
- Preserve all templates and documentation

### Option 2: Manual Cleanup

```bash
# Destroy infrastructure
cd terraform
terraform destroy

# Remove test results
rm -f results/test-*.md results/execution-log.txt

# Reset terraform config
rm terraform/terraform.tfvars
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

### Option 3: Simple Prompt to Claude

Just say: `cleanup test`

Claude will automatically clean up everything and prepare for the next test run.

### What Gets Cleaned vs What Stays

**Cleaned:**
- AWS infrastructure (EC2 instances, security groups, VPC resources) — verified
  against AWS after `terraform destroy`, not just the exit code
- Previous test results (implementation steps, verdict, report, logs)
- `results/deployment-outputs.md` — every credential, DNS name, IP and cert path
  from the last run; removed every time, never left on disk between tests
- Terraform state files and cache (including `.tfstate.backup`, which can retain
  the generated SSH private key in plaintext)
- User configuration (terraform.tfvars)

**Stays:**
- All templates and documentation
- Terraform infrastructure code
- Installation scripts
- Test instructions

---

## 🐛 Troubleshooting

### Infrastructure Deployment Fails

```bash
# Check terraform logs
cd terraform
terraform plan

# Verify AWS credentials resolve to the expected account
aws sts get-caller-identity --profile wazuh

# Check regional resources
aws ec2 describe-vpcs --region us-east-1 --profile wazuh
```

### SSH Connection Fails

```bash
# Verify key permissions (should be 600)
ls -la wazuh-test-key.pem

# Check security group
aws ec2 describe-security-groups --group-names wazuh-server-sg --profile wazuh

# Wait for instance readiness
aws ec2 describe-instance-status --instance-ids <instance-id> --profile wazuh
```

### Wazuh Services Not Running

```bash
# SSH to server first
ssh -i wazuh-test-key.pem ubuntu@<server-dns>

# Check services
sudo systemctl status wazuh-manager
sudo systemctl status wazuh-dashboard

# View logs
sudo tail -100 /var/ossec/logs/ossec.log

# Restart service if needed
sudo systemctl restart wazuh-manager
```

### Dashboard Not Accessible

```bash
# Verify service is running
sudo systemctl status wazuh-dashboard

# Check port is listening
sudo ss -tlnp | grep 443

# Verify security group allows 443
aws ec2 describe-security-groups --group-names wazuh-server-sg --profile wazuh
```

### Terraform State Issues

```bash
# Verify terraform.tfvars exists
ls -la terraform/terraform.tfvars

# Check terraform state
cd terraform
terraform state list

# Refresh state
terraform refresh
```

---

## 📞 Quick Reference

| Need | How |
|------|-----|
| **Start automated test** | Say "execute test" to Claude |
| **Clean up & start fresh** | Say "cleanup test" or run `./cleanup.ps1` / `bash cleanup.sh` |
| **SSH to server** | `ssh -i wazuh-test-key.pem ubuntu@<dns>` |
| **Access dashboard** | `https://<server-dns>` — credentials in `results/deployment-outputs.md` |
| **Extend TTL** | Edit `terraform/terraform.tfvars` → `terraform apply` |
| **Destroy infrastructure** | `cd terraform && terraform destroy` |
| **View test verdict** | `cat results/test-verdict.md` |
| **View PDF report** | `open results/test-report.pdf` |
| **View execution log** | `cat results/execution-log.txt` |

---

## 📚 Documentation Files

- **test/AUTOMATED_TEST_TEMPLATE.md** — Fill in the source document, then say "execute test".
  Product-agnostic; includes the rules (R1–R8) that keep a run honest and cheap.
- **test/TTL_AND_AUTO_TERMINATION.md** — How self-termination works, and why the
  previous cosmetic version cost ~$4.92 in forgotten instances
- **DEPLOYMENT_RUNBOOK.md** — Worked Wazuh + TheHive example: every failure hit,
  its root cause, and the fix. Read before editing the Terraform or init scripts.

---

## 🔗 References

- **Wazuh Documentation:** https://documentation.wazuh.com/current/
- **EndOfLife.date API:** https://endoflife.date/
- **Terraform AWS Provider:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs

---

**Last Updated:** 2026-07-27  
**Version:** 1.0  
**Status:** Ready for automated testing
