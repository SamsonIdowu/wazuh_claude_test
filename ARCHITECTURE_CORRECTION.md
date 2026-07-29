# Architecture Correction: Ephemeral Test Infrastructure

**Status**: Design only — implementation pending  
**Change**: Separate permanent baseline from test-specific infrastructure  

---

## Current Problem

Currently, the repository contains:
- ✅ Wazuh server + agent (permanent)
- ❌ TheHive (test-specific, permanently in repo)
- ❌ Test-specific security groups (permanently configured)
- ❌ Test-specific modules (v5_0_0, upgrade_4_to_5)
- ❌ Overly complex variables

**Result**: After a test, the repository is left in a different state than it started. Another agent cannot just `terraform apply` with the baseline; they inherit test-specific code.

---

## Correct Architecture

### What's Permanent (Always in Repo)

**Terraform (always deployed):**
- `terraform/main.tf` → Wazuh server EC2 + agent EC2 + VPC/networking
- `terraform/variables.tf` → Core variables only:
  - `wazuh_version` (what Wazuh version to deploy)
  - `aws_region`, `aws_profile`
  - `instance_types`, `volume_sizes`
  - `allowed_ssh_cidrs`, `allowed_api_cidrs`
  - `resource_ttl_minutes`, `enable_auto_termination`
- `terraform/wazuh-server-init.sh` → Server installation (version-agnostic)
- `terraform/wazuh-agent-init.sh` → Agent installation (version-agnostic)

**Documentation (never changes):**
- All `.md` files in `test/` and root
- Runbooks
- Templates

**Code Structure:**
```
terraform/
├── main.tf ← ONLY Wazuh server + agent
├── variables.tf ← ONLY core variables
├── wazuh-server-init.sh ← ONLY Wazuh server setup
├── wazuh-agent-init.sh ← ONLY Wazuh agent setup
└── terraform.tfvars.example ← Config template

(NO: versions/, NO thehive-init.sh, NO test-specific code)
```

**Result After Cleanup:** Repository is identical to initial state.

---

### What's Ephemeral (Created During Test, Deleted at Cleanup)

**Created when test starts:**
```
test/terraform/ (test-specific infrastructure)
├── thehive-security-group.tf ← Created for thehive_integration scenario
├── thehive-init.sh ← Created for thehive_integration scenario
├── additional-variables.tf ← Test-specific variables overlay
└── README.md ← Documents what to expect

results/ (test outputs)
├── test-verdict.md
├── execution-log.txt
└── ... (other test outputs)
```

**Deleted when test ends:**
```
# Cleanup procedure:
1. terraform destroy (removes AWS resources)
2. rm -rf test/terraform/ (removes test-specific code)
3. rm -rf results/ (removes test outputs)
4. Repository reverts to baseline
```

---

## Deployment Workflow

### Baseline Deployment (Always Works)

```bash
cd terraform
terraform init
terraform apply -var="wazuh_version=4.14.6"
```

**Result**: Wazuh server + agent, nothing else.
**Cost**: ~$0.21/hour
**Time**: 45 minutes

This should work for ANY agent, ANYTIME, no special setup.

---

### Test-Specific Deployment (Agent Generates, Cleanup Destroys)

Example: Testing Wazuh documentation or blog post

```bash
# 1. Agent reads the documentation/blog post to be tested
# 2. Agent analyzes and extracts requirements:
#    - What services are needed?
#    - What configuration is required?
#    - What scenario matches?

# 3. Agent GENERATES test-specific terraform code based on requirements:
cat > test/terraform/generated-test-config.tf << 'EOF'
# Generated from: https://docs.wazuh.com/...
# Test objective: Validate EOL detection blog post
# Required infrastructure:
#   - Wazuh server 4.14.6
#   - Wazuh agent
#   - Additional rules for EOL detection
#   - Security group rule for external API calls

resource "aws_security_group_rule" "external_api" {
  # Generated based on: "EOL detection requires external API access"
  ...
}

resource "local_file" "eol_detector_config" {
  # Generated based on: "Deploy eol_detector.py to /var/ossec/integrations"
  ...
}
EOF

# 4. Agent deploys with generated code:
cd terraform
terraform init
terraform apply
  # Sees test/terraform/*.tf and includes them
  # Deploys server + agent + generated test-specific config

# 5. Agent runs test according to documentation...

# 6. After test completes:
terraform destroy
rm -rf test/terraform/
# Repository is back to baseline
```

---

## File Organization

### Root `terraform/` (Permanent - Always Same)
```
terraform/
├── main.tf
│   ├── Wazuh server EC2
│   ├── Agent EC2
│   ├── Default security groups (SSH, manager comms, dashboard, API)
│   └── VPC/networking
├── variables.tf
│   ├── wazuh_version
│   ├── instance_types
│   ├── aws_region
│   ├── ttl_minutes
│   └── allowed_cidrs
├── wazuh-server-init.sh
│   ├── Version-agnostic installation
│   ├── Uses wazuh_version variable
│   └── Works for 4.14.6, 5.0.0, etc.
├── wazuh-agent-init.sh
│   ├── Version-agnostic installation
│   └── Enrolls to server
└── terraform.tfvars.example
```

### `test/` (Documentation + Test Procedures)
```
test/
├── README.md (test guidance)
├── TEST_SCENARIOS_GUIDE.md (7 scenarios)
├── DOCUMENTATION_TEST_TEMPLATE.md (framework for docs/blog posts)
├── UPGRADE_TEST_TEMPLATE.md (framework for upgrades)
├── deployments/ (procedures + runbooks)
│   ├── wazuh_4_14_6/RUNBOOK.md
│   ├── wazuh_5_0_0/RUNBOOK.md
│   └── upgrade_4_to_5/RUNBOOK.md
└── terraform/ ← GENERATED DURING TEST, DELETED AT CLEANUP
    ├── (empty when not testing)
    └── (agent GENERATES test-specific code from documentation)
```

**Key difference**: No static templates. Agent READS documentation and GENERATES appropriate test infrastructure.

---

## Cleanup Procedure (Corrected)

**After test completes (success or failure):**

```bash
# Step 1: Destroy infrastructure
cd terraform
terraform destroy -auto-approve

# Step 2: Delete test-specific code
rm -rf test/terraform/
rm -rf results/

# Step 3: Verify baseline is ready
terraform validate
# Should show only Wazuh server + agent

# Step 4: Repository is back to baseline state
git status
# Should show only version-controlled files unchanged
```

**Result**: 
- AWS resources: gone
- Test-specific code: deleted
- Test results: deleted
- Repository: baseline state

Another agent can now clone and deploy without inheriting test artifacts.

---

## What Each Test Generates

### Baseline Test (No Documentation)
- **Generates**: Nothing (uses baseline terraform)
- **Deploys**: Wazuh server + agent
- **Cost**: $0.21
- **Cleanup**: terraform destroy

### Testing a Blog Post (e.g., EOL Detection)
- **Input**: Blog post/documentation URL
- **Agent analyzes**: What infrastructure, config, rules are needed?
- **Generates**:
  - test/terraform/test-config.tf (security groups, any extra resources)
  - test/terraform/test-init.sh (custom configuration/rules)
  - test/terraform/test-variables.tf (scenario-specific variables)
- **Deploys**: Wazuh server + agent + blog post requirements
- **Cost**: Depends on generated infrastructure ($0.21-0.53)
- **Cleanup**: terraform destroy + rm -rf test/terraform/

### Testing Wazuh Documentation
- **Input**: Documentation URL (e.g., docs.wazuh.com/installation-guide/)
- **Agent analyzes**: What version? What features? What procedures?
- **Generates**:
  - test/terraform/test-config.tf (documentation requirements)
  - test/terraform/verification-rules.tf (checks to validate docs)
- **Deploys**: Wazuh server + agent configured per documentation
- **Cost**: $0.42-0.84 (comprehensive testing)
- **Cleanup**: terraform destroy + rm -rf test/terraform/

### Testing Upgrade Path
- **Input**: "Test 4.14.6 → 5.0.0 upgrade"
- **Agent generates**:
  - test/terraform/upgrade-baseline.tf (4.14.6 baseline)
  - test/terraform/upgrade-checks.tf (before/after verification)
- **Deploys**: 4.14.6 baseline (prepared for upgrade)
- **Cost**: $0.44
- **Cleanup**: terraform destroy + rm -rf test/terraform/

---

## Changes Needed

### Phase 1: Remove Permanent Test Code
- [ ] Remove `terraform/thehive-init.sh` → move to `test/templates/`
- [ ] Remove `terraform/versions/` directory → content goes to `test/templates/`
- [ ] Remove TheHive configuration from `terraform/main.tf`
- [ ] Remove test-specific variables from `terraform/variables.tf`
- [ ] Remove TheHive from `terraform/outputs.tf`
- [ ] Simplify `terraform/main.tf` to baseline only

### Phase 2: Create Test Requirements Directory
- [ ] Create `test/requirements/` directory for test-specific code snippets
  - Not Terraform (Terraform is generated per test)
  - Shell scripts, configuration files, Python scripts that tests might need
  - Example: `eol_detector.py`, `custom-rules.xml`, etc.
  - Agent pulls these when generating test infrastructure
- [ ] Document what's available and when to use it

### Phase 3: Create Cleanup Script
- [ ] Update `cleanup.ps1` to:
  1. terraform destroy
  2. rm -rf test/terraform/
  3. rm -rf results/
  4. Verify baseline state
  5. Confirm cleanup complete

### Phase 4: Update Documentation
- [ ] Update `AGENT_HANDOFF.md` with new cleanup procedure
- [ ] Update test templates to show cleanup
- [ ] Document how agents create test-specific code
- [ ] Show before/after repository state

---

## Before & After

### Before (Current - Wrong)
```
After test cleanup, repository contains:
├── terraform/
│   ├── main.tf ← mixed baseline + test code
│   ├── variables.tf ← mixed baseline + test variables
│   ├── thehive-init.sh ← test-specific
│   ├── versions/ ← test-specific
│   │   ├── v4_14_6/
│   │   ├── v5_0_0/
│   │   └── upgrade_4_to_5/
│   └── terraform.tfvars ← user config

Result: Repository is different from initial state.
        Another agent inherits test-specific code.
```

### After (Correct)
```
After test cleanup, repository contains:
├── terraform/
│   ├── main.tf ← baseline only
│   ├── variables.tf ← baseline only
│   ├── wazuh-server-init.sh ← baseline only
│   ├── wazuh-agent-init.sh ← baseline only
│   └── terraform.tfvars.example ← template

├── test/
│   ├── templates/ ← code to use during tests
│   │   ├── thehive-security-group.tf
│   │   ├── thehive-init.sh
│   │   └── README.md
│   ├── terraform/ ← EMPTY (only during active test)

Result: Repository is identical to initial state.
        Another agent can clone fresh and deploy immediately.
```

---

## How Agents Use This

### First-Time Agent (Baseline Only)

```bash
git clone <repo>
cd terraform
terraform apply -var="wazuh_version=4.14.6"
# Works immediately, no test-specific code
```

### Agent Testing a Blog Post or Documentation

```bash
# 1. User provides: "Test this blog post: https://example.com/eol-detection"
# 2. Agent reads the documentation/blog post
# 3. Agent analyzes: "This requires EOL detector, external API access, custom rules"
# 4. Agent GENERATES test-specific Terraform code:
cat > test/terraform/generated-test.tf << 'EOF'
# Generated from analysis of: https://example.com/eol-detection
# Generated requirements:
#   - Wazuh 4.14.6 server
#   - Agent for data collection
#   - Security group rule for external API (EOL detection service)
#   - Installation of eol_detector.py script

resource "aws_security_group_rule" "eol_api_access" {
  # Generated: "Blog requires external API calls to endoflife.date"
  ...
}

resource "local_file" "eol_detector_script" {
  # Generated: "Deploy custom Python script for EOL detection"
  filename = "/var/ossec/integrations/eol_detector.py"
  content  = file("${path.module}/../test-requirements/eol_detector.py")
}
EOF

# 5. Agent deploys:
cd terraform
terraform apply

# 6. Agent tests according to the blog post procedures
# 7. Agent documents findings in test-verdict.md

# 8. Agent cleans up:
terraform destroy
rm -rf test/terraform/
# Repository is back to baseline
```

### Agent Testing Wazuh 5.0.0 Documentation

```bash
# 1. User provides: "Validate Wazuh 5.0.0 installation docs"
# 2. Agent reads: https://docs.wazuh.com/5.0/installation-guide/
# 3. Agent analyzes: "Requires Ubuntu 22.04, t3.xlarge, specific security ports"
# 4. Agent GENERATES test infrastructure:
cat > test/terraform/generated-documentation-test.tf << 'EOF'
# Generated from: https://docs.wazuh.com/5.0/installation-guide/
# Test: Validate documented installation procedure works on 5.0.0

resource "aws_instance" "wazuh_5_0_server" {
  # Generated: "Docs require Ubuntu 22.04 LTS"
  ami = data.aws_ami.ubuntu_22_04.id
  
  user_data = base64encode(<<-SCRIPT
    # Generated: "Follow exact installation steps from documentation"
    curl -sO https://packages.wazuh.com/5.0/wazuh-install.sh
    bash ./wazuh-install.sh -a -i
  SCRIPT
  )
}

resource "local_file" "verification_procedures" {
  # Generated: "Document verification steps from docs"
  filename = "/tmp/doc-verification.sh"
  content  = <<-SCRIPT
    # Generated verification rules from documentation
    echo "Checking: Services running"
    systemctl is-active wazuh-manager wazuh-indexer wazuh-dashboard
  SCRIPT
}
EOF

# 5. Agent deploys with generated requirements:
terraform apply

# 6. Agent executes documentation procedures and verifies they work

# 7. Agent cleans up:
terraform destroy
rm -rf test/terraform/
```

### Agent Testing Upgrade Path

```bash
# 1. User provides: "Test 4.14.6 → 5.0.0 upgrade"
# 2. Agent reads: test/deployments/upgrade_4_to_5/RUNBOOK.md and UPGRADE_TEST_TEMPLATE.md
# 3. Agent analyzes: "Need 4.14.6 baseline, then upgrade to 5.0.0"
# 4. Agent GENERATES upgrade test infrastructure:
cat > test/terraform/generated-upgrade-test.tf << 'EOF'
# Generated for: 4.14.6 → 5.0.0 upgrade testing
# Phase 1: Deploy 4.14.6 baseline
# Phase 2: Run upgrade script
# Phase 3: Verify 5.0.0

resource "local_file" "backup_procedure" {
  # Generated: "Before upgrade, backup current installation"
  filename = "/tmp/backup.sh"
  content  = "tar -czf /root/wazuh-4.14.6-backup.tar.gz /var/ossec /etc/wazuh-*"
}

resource "local_file" "upgrade_verification" {
  # Generated: "After upgrade, verify services and data"
  filename = "/tmp/verify-upgrade.sh"
  content  = <<-SCRIPT
    sudo /var/ossec/bin/wazuh-control info
    # Expected: Manager 5.0.0
  SCRIPT
}
EOF

# 5. Agent deploys 4.14.6 baseline:
terraform apply

# 6. Agent follows UPGRADE_TEST_TEMPLATE.md procedures
# 7. Agent documents upgrade success/issues
# 8. Agent cleans up:
terraform destroy
rm -rf test/terraform/
```

---

## Summary

| Aspect | Before | After |
|--------|--------|-------|
| **Permanent code** | Mixed baseline + test | Baseline only |
| **Test code location** | terraform/ (permanent) | test/terraform/ (GENERATED per test, ephemeral) |
| **Test creation** | Copy static templates | ANALYZE documentation, GENERATE requirements |
| **After cleanup** | Different from initial | Identical to initial |
| **First-time deploy** | Must ignore test code | Works directly |
| **Adding new test** | Modify permanent files | Agent reads docs, generates infrastructure |
| **Repository state** | Carries test artifacts | Always clean baseline |

---

## Next Steps

1. **Do NOT implement yet** — confirm this architecture is what you want
2. Once approved:
   - Remove test-specific code from terraform/
   - Create test/templates/ structure
   - Move code to templates
   - Update cleanup scripts
   - Update documentation
   - Test the flow: deploy → test → cleanup → verify baseline

---

**This ensures**: Any agent can deploy the baseline. Tests can add infrastructure without polluting the repo. Cleanup removes ALL test artifacts. Repository returns to pristine state.

