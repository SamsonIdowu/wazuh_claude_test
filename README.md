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

### Option 2: Manual Infrastructure + Tests

1. Create `terraform/terraform.tfvars` with your AWS credentials and IP
2. Run `terraform init && terraform apply`
3. SSH to instances and manually run tests
4. Document results

---

## 📁 Project Structure

```
wazuh_test/
├── README.md                           (This file - main documentation)
├── setup.ps1 / setup.sh               (Auto-detect IP, create terraform.tfvars)
├── terraform/
│   ├── main.tf                        (EC2, security groups, networking)
│   ├── variables.tf                   (Configurable parameters)
│   ├── outputs.tf                     (Connection details)
│   ├── wazuh-server-init.sh          (Server installation)
│   ├── wazuh-agent-init.sh           (Agent installation)
│   └── terraform.tfvars               (Your config - create this)
├── test/
│   ├── AUTOMATED_TEST_TEMPLATE.md    (Self-executing test template)
│   ├── EXECUTE_TEST_GUIDE.txt        (Quick start for automated tests)
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

The automated test system dynamically adapts infrastructure to match your document requirements.

### How It Works

**6 Automated Phases:**

1. **Document Analysis (5 min)**
   - Reads your Google Drive document
   - Extracts infrastructure requirements
   - Identifies test implementation steps

2. **Test Planning & Infrastructure Analysis (10 min)**
   - Identifies instance types, OS versions, component versions
   - Generates `terraform/terraform.tfvars` from requirements
   - Updates terraform variables if needed
   - Creates `Results/test-implementation-steps.md`

3. **Infrastructure Setup (10 min)**
   - Runs `setup.ps1` for IP auto-detection
   - Executes `terraform init && terraform plan && terraform apply`
   - Waits 5-10 minutes for services to initialize

4. **Test Execution (10-15 min)**
   - SSH to Wazuh server
   - Deploys configurations from document
   - Executes test steps sequentially
   - Captures all outputs

5. **Results & Verdict (5 min)**
   - Creates `Results/test-verdict.md` (PASS/FAIL/PARTIAL)
   - Creates `Results/test-details.md` (findings)
   - Generates `Results/execution-log.txt` (timeline)

6. **Cleanup (auto-managed)**
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

### Variable Infrastructure, Constant Tests

**Architecture Design:**
- Infrastructure (instance types, OS, versions, storage) is **variable** based on your document
- Test procedures, SSH commands, and execution flow are **constant**
- Results show exactly what infrastructure was used and tested

This allows testing any Wazuh configuration without modifying test procedures.

### To Use Automated Testing

1. **Update Template:**
   ```bash
   # Edit test/AUTOMATED_TEST_TEMPLATE.md
   # Add your Google Drive document link in the Configuration section
   # Save the file
   ```

2. **Execute:**
   ```
   Message Claude: "execute test"
   ```

3. **View Results:**
   ```bash
   # After 20-40 minutes, check:
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
- Your public IP address

### Step 1: Auto-Detect Your IP (Optional)

**On Windows:**
```powershell
.\setup.ps1
```

**On Linux/Mac:**
```bash
bash setup.sh
```

This creates `terraform/terraform.tfvars` with your detected IP in security group CIDR blocks.

### Step 2: Create Terraform Configuration

If not using setup script, create `terraform/terraform.tfvars`:

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

### Step 3: Deploy

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Terraform will output:
- Wazuh server public DNS
- Wazuh agent public DNS
- SSH key path
- Dashboard URL
- TTL countdown

### Step 4: Access Resources

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

### Step 5: Verify Services

```bash
# On Wazuh server:
sudo systemctl status wazuh-manager
sudo systemctl status wazuh-dashboard
sudo systemctl status wazuh-indexer

# View logs if needed:
sudo tail -50 /var/ossec/logs/ossec.log
```

### Step 6: Run Tests

Follow your test procedures from the blog post:
1. Deploy EOL detector script
2. Configure Wazuh rules
3. Add log collectors
4. Generate test data
5. Verify alerts in dashboard

### Step 7: Document Results

Create test result files in `Results/`:
- `test-implementation-steps.md` - What you tested
- `test-verdict.md` - PASS/FAIL/PARTIAL summary
- `test-details.md` - Detailed findings

---

## 🏗️ Infrastructure Details

### Deployed Components

**Wazuh Server (Ubuntu 22.04)**
- Instance Type: `t3.xlarge` (customizable)
- Root Volume: 30 GB (gp3, encrypted)
- Services:
  - Wazuh Manager 4.14.6
  - Wazuh Dashboard 4.14.6
  - Wazuh Indexer 4.14.6
- Cost: ~$0.17/hour
- Security Group:
  - SSH (22) from your IP
  - Dashboard (443) from anywhere
  - API (55000) from your IP
  - Agent comms (1514) from anywhere

**Wazuh Agent (Ubuntu 24.04)**
- Instance Type: `t3.medium` (customizable)
- Root Volume: 20 GB (gp3, encrypted)
- Services:
  - Wazuh Agent 4.14.6 (auto-enrolled)
- Cost: ~$0.04/hour
- Security Group:
  - SSH (22) from your IP
  - Agent comms (1514) from Wazuh server only

### Single Version Variable

Change Wazuh version for all components with one variable:

```hcl
wazuh_version = "4.14.6"  # Updates Manager, Dashboard, Indexer, Agent
```

### Security Features

- **Auto-detected IP:** Setup scripts detect your public IP automatically
- **Encrypted volumes:** Root volumes use gp3 with encryption enabled
- **IMDSv2 enforced:** Instance metadata requires secure tokens
- **Restricted SSH:** SSH restricted to your IP by default
- **Public dashboard:** Dashboard accessible from internet (not manager)

---

## ⏱️ Managing Resources

### TTL (Time-To-Live)

Default: **1 hour** with auto-termination

### Extend TTL

Edit `terraform/terraform.tfvars`:
```hcl
resource_ttl_minutes = 120  # 2 hours
```

Then:
```bash
cd terraform
terraform apply
```

### Disable Auto-Termination

Edit `terraform/terraform.tfvars`:
```hcl
enable_auto_termination = false
```

Then:
```bash
cd terraform
terraform apply
```

### Cleanup

Immediately terminate resources:
```bash
cd terraform
terraform destroy
```

### Cost Estimates

| Duration | Monthly Cost | Test Cost |
|----------|--------------|-----------|
| 1 hour | N/A | ~$0.21 |
| 2 hours | N/A | ~$0.42 |
| 4 hours | N/A | ~$0.84 |
| 8 hours | N/A | ~$1.68 |
| Full day (24h) | N/A | ~$5.04 |

---

## 📊 Test Results

### Output Files (in Results/ Directory)

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
- Resource URLs
- Connection details
- Service status at each step

---

## 🔧 Configuration Reference

### Required Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `aws_region` | string | us-east-1 | AWS region |
| `wazuh_version` | string | 4.14.6 | Wazuh version (affects all components) |

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
| `allowed_ssh_cidrs` | list | 0.0.0.0/0 | CIDR blocks for SSH |
| `allowed_api_cidrs` | list | 0.0.0.0/0 | CIDR blocks for API |

### TTL Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `resource_ttl_minutes` | number | 60 | Auto-termination timeout (1-1440 min) |
| `enable_auto_termination` | bool | true | Enable auto-cleanup |

---

## 🧹 Cleanup & Fresh Start

### After Testing is Complete

To clean up from a previous test and prepare for a new one:

**Option 1: Use cleanup script**

Windows (PowerShell):
```powershell
.\cleanup.ps1
```

Linux/Mac (Bash):
```bash
bash cleanup.sh
```

**Option 2: Manual cleanup**

```bash
# Destroy infrastructure
cd terraform
terraform destroy

# Remove test results
rm -f Results/test-*.md Results/execution-log.txt

# Reset terraform config
rm terraform/terraform.tfvars
cp terraform.tfvars.example terraform/terraform.tfvars
```

**Option 3: Simple prompt to Claude**

Just say: `cleanup test`

Claude will automatically clean up and prepare for the next test run.

### What Gets Cleaned

- ✅ AWS infrastructure (EC2 instances, security groups, VPC resources)
- ✅ Previous test results (implementation steps, verdict, details, logs)
- ✅ Terraform state files
- ✅ Terraform cache and lock files
- ✅ User configuration (terraform.tfvars)

### What Stays

- ✅ All templates and documentation
- ✅ Terraform code (main.tf, variables.tf, outputs.tf)
- ✅ Installation scripts
- ✅ Test instructions

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
# Verify key permissions
ls -la wazuh-test-key.pem  # Should be 600

# Check security group
aws ec2 describe-security-groups --group-names wazuh-server-sg

# Wait for instance readiness
aws ec2 describe-instance-status --instance-ids <instance-id>
```

### Wazuh Services Not Running

```bash
# SSH to server
ssh -i wazuh-test-key.pem ubuntu@<server-dns>

# Check services
sudo systemctl status wazuh-manager
sudo systemctl status wazuh-dashboard

# View logs
sudo tail -100 /var/ossec/logs/ossec.log

# Restart if needed
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
| **Clean up & start fresh** | Say "cleanup test" to Claude, or run `./cleanup.ps1` / `bash cleanup.sh` |
| **SSH to server** | `ssh -i wazuh-test-key.pem ubuntu@<dns>` |
| **View dashboard** | `https://<server-dns>` |
| **Extend TTL** | Edit `terraform/terraform.tfvars` → `terraform apply` |
| **Manually destroy** | `cd terraform && terraform destroy` |
| **View test verdict** | `cat Results/test-verdict.md` |
| **View test details** | `cat Results/test-details.md` |
| **View timeline** | `cat Results/execution-log.txt` |

---

## 📚 Documentation Files

- **test/AUTOMATED_TEST_TEMPLATE.md** — Self-executing test template with Google Drive link
- **test/EXECUTE_TEST_GUIDE.txt** — Quick start guide for automated testing
- **test/TTL_AND_AUTO_TERMINATION.md** — Complete TTL management guide
- **test/TTL_SUMMARY.txt** — Quick reference for TTL features

---

## 🔗 References

- **Blog Post:** Monitoring end-of-life software with Wazuh
- **Wazuh Documentation:** https://documentation.wazuh.com/current/
- **EndOfLife.date API:** https://endoflife.date/
- **Terraform AWS Provider:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs

---

## 📝 Architecture Notes

### Variable Infrastructure, Constant Tests

- **Infrastructure** (instance types, OS, versions, storage) is determined from document requirements
- **Test procedures** (SSH commands, service checks, test flow) remain standardized
- **Results** clearly show what infrastructure was deployed and tested

### Why This Design?

This architecture allows you to test any Wazuh configuration without modifying test procedures. Each test extracts infrastructure requirements from a document and automatically configures terraform accordingly.

---

## 🎯 Workflow

```
Google Drive Document (with requirements)
         ↓
   Step 1: Upload Google Drive link to test/AUTOMATED_TEST_TEMPLATE.md
         ↓
   Step 2: Say "execute test" to Claude
         ↓
   Step 3: Claude automatically:
      - Reads document
      - Extracts requirements
      - Generates terraform.tfvars
      - Deploys infrastructure
      - Runs tests
      - Documents results
         ↓
   Step 4: Review results in Results/ folder
         ↓
   Step 5: Resources auto-terminate after 1 hour (or manually cleanup)
```

---

**Last Updated:** 2026-07-27  
**Version:** 1.0  
**Status:** Ready for automated testing
