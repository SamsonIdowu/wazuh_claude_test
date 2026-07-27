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

## 🚀 Quick Start

### Option 1: Automated Testing (Recommended)

1. Edit `test/AUTOMATED_TEST_TEMPLATE.md`
2. Add your Google Drive document link in the Configuration section
3. Save the file
4. Message Claude: **"execute test"**
5. Wait 20-40 minutes
6. Check `Results/` folder for test outputs

### Option 2: Manual Deployment

1. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars`
2. Edit with your AWS credentials and IP address
3. Run `cd terraform && terraform init && terraform apply`
4. SSH to instances and manually run tests
5. Document results in `Results/` folder

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
│   ├── wazuh-server-init.sh          (Server installation)
│   ├── wazuh-agent-init.sh           (Agent installation)
│   ├── terraform.tfvars.example       (Config template - copy this)
│   └── terraform.tfvars               (Your config - create from example)
├── test/
│   ├── AUTOMATED_TEST_TEMPLATE.md    (Self-executing test template)
│   ├── EXECUTE_TEST_GUIDE.txt        (Quick start for automated tests)
│   ├── README.md                     (Test documentation index)
│   ├── TTL_AND_AUTO_TERMINATION.md   (TTL management guide)
│   └── TTL_SUMMARY.txt               (Quick reference)
└── Results/                           (Test outputs - auto-generated)
    ├── test-implementation-steps.md
    ├── test-verdict.md
    ├── test-details.md
    └── execution-log.txt
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
- Creates `Results/test-implementation-steps.md` with test procedures
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
- Creates `Results/test-verdict.md` (PASS/FAIL/PARTIAL)
- Creates `Results/test-details.md` (detailed findings)
- Generates `Results/execution-log.txt` (timeline)

**Phase 6: Cleanup (auto-managed)**
- Auto-terminates after 1 hour (default)
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
10:45 AM - Results available in Results/ folder
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
cat Results/test-verdict.md        # Pass/Fail summary
cat Results/test-details.md        # Full findings
cat Results/execution-log.txt      # Timeline
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
wazuh_version              = "4.14.6"
wazuh_server_instance_type = "t3.xlarge"
agent_instance_type        = "t3.medium"
allowed_ssh_cidrs          = ["YOUR_IP/32"]
allowed_api_cidrs          = ["YOUR_IP/32"]
resource_ttl_minutes       = 60          # 1 hour default
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
```
URL: https://<server_public_dns>
User: admin
Password: admin (default)
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

Follow your test procedures from the blog post:
1. Deploy EOL detector script
2. Configure Wazuh rules
3. Add log collectors
4. Generate test data
5. Verify alerts in dashboard

### Step 6: Document Results

Create test result files in `Results/`:
- `test-implementation-steps.md` — What you tested
- `test-verdict.md` — PASS/FAIL/PARTIAL summary
- `test-details.md` — Detailed findings

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

**Default:** 1 hour with auto-termination

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

Test results are stored in the `Results/` directory with these files:

**test-implementation-steps.md**
- What was tested
- Infrastructure used
- Configuration changes made
- Blog post steps mapped to test procedures

**test-verdict.md**
- Overall result: PASS / FAIL / PARTIAL
- Summary of findings
- Recommendations for next steps

**test-details.md**
- Complete findings and logs
- SSH command outputs
- Configuration files used
- Errors and solutions
- Full audit trail

**execution-log.txt**
- Timeline of all events
- Phase completion times
- Resource URLs and connection details
- Service status at each step

---

## 🔧 Configuration Reference

### Required Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `aws_region` | string | us-east-1 | AWS region for deployment |
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
| `resource_ttl_minutes` | number | 60 | Auto-termination timeout (1-1440 minutes) |
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
rm -f Results/test-*.md Results/execution-log.txt

# Reset terraform config
rm terraform/terraform.tfvars
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

### Option 3: Simple Prompt to Claude

Just say: `cleanup test`

Claude will automatically clean up everything and prepare for the next test run.

### What Gets Cleaned vs What Stays

**Cleaned:**
- AWS infrastructure (EC2 instances, security groups, VPC resources)
- Previous test results (implementation steps, verdict, details, logs)
- Terraform state files and cache
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

# Verify AWS credentials
aws sts get-caller-identity

# Check regional resources
aws ec2 describe-vpcs --region us-east-1
```

### SSH Connection Fails

```bash
# Verify key permissions (should be 600)
ls -la wazuh-test-key.pem

# Check security group
aws ec2 describe-security-groups --group-names wazuh-server-sg

# Wait for instance readiness
aws ec2 describe-instance-status --instance-ids <instance-id>
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
aws ec2 describe-security-groups --group-names wazuh-server-sg
```

### EOL Detector Script Fails

```bash
# SSH to server
ssh -i wazuh-test-key.pem ubuntu@<server-dns>

# Check script exists
ls -la /var/ossec/integrations/eol_detector.py

# Fix permissions
sudo chown wazuh:wazuh /var/ossec/integrations/eol_detector.py
sudo chmod 750 /var/ossec/integrations/eol_detector.py

# Test manually
sudo python3 /var/ossec/integrations/eol_detector.py 2>&1
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
| **Access dashboard** | `https://<server-dns>` (admin/admin) |
| **Extend TTL** | Edit `terraform/terraform.tfvars` → `terraform apply` |
| **Destroy infrastructure** | `cd terraform && terraform destroy` |
| **View test verdict** | `cat Results/test-verdict.md` |
| **View test details** | `cat Results/test-details.md` |
| **View execution log** | `cat Results/execution-log.txt` |

---

## 📚 Documentation Files

- **test/AUTOMATED_TEST_TEMPLATE.md** — Self-executing test template (edit to add Google Drive link)
- **test/EXECUTE_TEST_GUIDE.txt** — Quick start guide for automated testing
- **test/TTL_AND_AUTO_TERMINATION.md** — Complete Time-To-Live management guide
- **test/TTL_SUMMARY.txt** — Quick reference card for TTL features

---

## 🔗 References

- **Wazuh Documentation:** https://documentation.wazuh.com/current/
- **EndOfLife.date API:** https://endoflife.date/
- **Terraform AWS Provider:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs

---

**Last Updated:** 2026-07-27  
**Version:** 1.0  
**Status:** Ready for automated testing
