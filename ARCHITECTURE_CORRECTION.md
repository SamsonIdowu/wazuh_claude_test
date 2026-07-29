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

### Test-Specific Deployment (Test Creates, Cleanup Destroys)

Example: TheHive integration test

```bash
# Agent (before test) creates test-specific code:
cat > test/terraform/thehive-security-group.tf << 'EOF'
# TheHive security group configuration
# Created during: thehive_integration test
# Deleted during: cleanup
resource "aws_security_group" "thehive" {
  ...
}
EOF

# Agent extends variables:
cat > test/terraform/additional-variables.tf << 'EOF'
variable "deploy_thehive" {
  default = true
}
EOF

# Agent creates init script:
cp test/templates/thehive-init.sh test/terraform/

# Agent deploys:
cd terraform
terraform init
terraform apply -var="wazuh_version=4.14.6"
  # Sees test/terraform/*.tf and includes them
  # Deploys server + agent + thehive

# Agent runs test...

# After test succeeds:
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

### `test/` (Documentation + Templates)
```
test/
├── README.md (test guidance)
├── TEST_SCENARIOS_GUIDE.md (7 scenarios)
├── DOCUMENTATION_TEST_TEMPLATE.md
├── UPGRADE_TEST_TEMPLATE.md
├── templates/ ← Templates for test-specific code
│   ├── thehive-security-group.tf.template
│   ├── thehive-init.sh.template
│   ├── upgrade-modules.tf.template
│   └── etc.
├── deployments/ (procedures + runbooks)
│   ├── wazuh_4_14_6/RUNBOOK.md
│   ├── wazuh_5_0_0/RUNBOOK.md
│   └── upgrade_4_to_5/RUNBOOK.md
└── terraform/ ← CREATED DURING TEST, DELETED AT CLEANUP
    ├── (empty, except during active test)
    └── (agent populates with test-specific code)
```

### `test/templates/` (New - Code Templates for Tests)

Rather than permanently storing test-specific code, store TEMPLATES:

```
test/templates/
├── thehive-security-group.tf
│   # Describes TheHive security group needed
│   # Agent copies to test/terraform/ when running thehive_integration test
├── thehive-init.sh
│   # TheHive installation script
│   # Agent copies to test/terraform/ when needed
├── upgrade-v5-modules.tf
│   # Wazuh 5.0.0 module for upgrade testing
│   # Agent copies during upgrade_4_to_5 test
└── README.md
    # Documents what each template is for
    # Which test uses it
    # What it deploys
```

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

## What Each Test Type Creates

### `fresh_deployment` Scenario
- **Creates**: Nothing (uses baseline)
- **Deploys**: Wazuh server + agent
- **Cost**: $0.21
- **Cleanup**: terraform destroy

### `eol_detection` Scenario
- **Creates**: Nothing (uses baseline)
- **Deploys**: Wazuh server + agent
- **Cost**: $0.32
- **Cleanup**: terraform destroy

### `documentation_test` Scenario
- **Creates**: Nothing (uses baseline)
- **Deploys**: Wazuh server + agent
- **Cost**: $0.42-0.84
- **Cleanup**: terraform destroy

### `thehive_integration` Scenario
- **Creates**: 
  - test/terraform/thehive-security-group.tf
  - test/terraform/thehive-init.sh
  - test/terraform/additional-variables.tf
- **Deploys**: Wazuh server + agent + TheHive
- **Cost**: $0.53
- **Cleanup**: terraform destroy + rm -rf test/terraform/

### `upgrade_4_to_5` Scenario
- **Creates**:
  - test/terraform/upgrade-support.tf (extra checks/logging)
  - test/terraform/upgrade-variables.tf (upgrade-specific vars)
- **Deploys**: Wazuh 4.14.6 server + agent (baseline for upgrade)
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

### Phase 2: Create Test Templates
- [ ] Create `test/templates/` directory
- [ ] Move TheHive code → `test/templates/thehive-security-group.tf`
- [ ] Move TheHive init → `test/templates/thehive-init.sh`
- [ ] Create templates for upgrade scenario
- [ ] Document what each template does

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

### Agent Running TheHive Test

```bash
# 1. Read test/TEST_SCENARIOS_GUIDE.md → pick thehive_integration
# 2. Read test/templates/README.md → understand what's needed
# 3. Copy templates to test/terraform/
cp test/templates/thehive-security-group.tf test/terraform/
cp test/templates/thehive-init.sh test/terraform/
# 4. Deploy
cd terraform
terraform apply
# 5. Test...
# 6. Cleanup
terraform destroy
rm -rf test/terraform/
# 7. Repository is baseline again
```

### Agent Running Upgrade Test

```bash
# 1. Read test/deployments/upgrade_4_to_5/RUNBOOK.md
# 2. Copy upgrade templates
cp test/templates/upgrade-*.tf test/terraform/
# 3. Deploy (starts on 4.14.6 baseline)
terraform apply
# 4. Follow upgrade procedure from RUNBOOK.md
# 5. Cleanup
terraform destroy
rm -rf test/terraform/
```

---

## Summary

| Aspect | Before | After |
|--------|--------|-------|
| **Permanent code** | Mixed baseline + test | Baseline only |
| **Test code location** | terraform/ (permanent) | test/templates/ + test/terraform/ (ephemeral) |
| **After cleanup** | Different from initial | Identical to initial |
| **First-time deploy** | Must ignore test code | Works directly |
| **Adding new test** | Modify permanent files | Add template, no repo change |
| **Repository state** | Carries test artifacts | Always clean |

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

