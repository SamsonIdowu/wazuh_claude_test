# Wazuh Testing Infrastructure — Improvement Recommendations

## Executive Summary

**Current state**: Wazuh 4.14.6 + TheHive 5 working end-to-end with comprehensive deployment runbook.

**Proposed improvements**:
1. Dual-version support (4.14.6 and 5.0.0)
2. Version-specific deployment runbooks
3. Documentation testing mode
4. Test matrix (version × scenario)
5. Automated upgrade path testing
6. Enhanced cost tracking and diagnostics

---

## 1. Dual-Version Support Architecture

### Problem
- Single `wazuh_version` variable doesn't capture version-specific differences
- Wazuh 4.x and 5.x have incompatible installation procedures
- 5.0 introduces breaking changes (Indexer certificates, Dashboard auth, API endpoints)
- Single `variables.tf` becomes unreadable with 20+ version conditionals

### Solution: Version-Specific Modules

```
terraform/
├── main.tf                     (orchestrator — routes to version modules)
├── variables.tf                (common vars + version selection)
├── versions/
│   ├── v4_14_6/
│   │   ├── main.tf            (Wazuh 4.14.6 server resources)
│   │   ├── variables.tf        (4.14.6-specific vars)
│   │   └── wazuh-server-init.sh
│   └── v5_0_0/
│       ├── main.tf            (Wazuh 5.0.0 server resources)
│       ├── variables.tf        (5.0.0-specific vars)
│       └── wazuh-server-init.sh
└── shared/
    ├── agent/                 (mostly version-agnostic)
    └── thehive/               (independent of Wazuh version)
```

**Benefits**:
- Maintainability: Each version's gotchas isolated
- Readability: No version-conditional spaghetti
- Testability: Can test both versions simultaneously
- Upgrade testing: Can deploy 4.14.6 alongside 5.0

---

## 2. Version-Specific Deployment Runbooks

### Wazuh 4.14.6 ✅ (Exists)
**Location**: `test/DEPLOYMENT_RUNBOOK.md`

Covers:
- Quickstart installer usage
- Certificate issues (Indexer localhost-only binding)
- Password retrieval
- Verification commands

### Wazuh 5.0.0 (Needs Creation)
**Location**: `test/deployments/wazuh_5_0_0/RUNBOOK.md`

Should document:
1. **Installation differences**
   - URL format (e.g., is it `/5.x/` like 4.x uses `/4.x/`?)
   - New dashboard authentication flow?
   - Indexer SSL certificate generation changes?
   - Breaking API endpoint changes?

2. **Known issues** (from research)
   - Equivalent to "Indexer binds to localhost only"?
   - Default credentials format?
   - Agent enrollment flow differences?

3. **Verification procedures**
   - Updated health checks (API endpoints may differ)
   - Dashboard login verification
   - Agent re-enrollment process

---

## 3. Documentation Testing Mode

### Problem
- Current tests are task-focused: "Does the EOL detector work?"
- No systematic way to validate all docs are accurate

### Solution: Documentation Validator Template

**New file**: `test/DOCUMENTATION_TEST_TEMPLATE.md`

```markdown
## Documentation Testing — Validate docs match reality

Source: Wazuh 5.0 Official Documentation

### Test Scope
- [ ] Installation guide matches actual installer URL
- [ ] API endpoints listed in docs work
- [ ] Default credentials work (if docs claim they do)
- [ ] Screenshots/UI elements match actual dashboard
- [ ] CLI commands produce expected output
- [ ] Configuration file syntax is correct

### Procedure
1. Deploy infrastructure from AUTOMATED_TEST_TEMPLATE
2. For each doc section:
   - Read the documented procedure
   - Follow it exactly on deployed infrastructure
   - Record success/failure + actual output
3. Compare documented vs actual
4. Report discrepancies
```

**Use case**: When Wazuh releases new docs:
- Catch doc errors before release
- Identify which procedures work
- Capture actual outputs for doc screenshots
- Verify all API endpoints are current

---

## 4. Test Matrix — Version × Scenario

### Current State
- Single test: "Does Wazuh + TheHive + EOL detector work on 4.14.6?"

### Proposed Matrix

```
                     | 4.14.6 | 5.0.0 | 5.1.0 (future)
---------------------|--------|-------|---------------
Fresh deployment     |   ✅   |  TBD  |   TBD
Blog post EOL        |   ✅   |  TBD  |   TBD
Documentation test   |   📋   |  📋   |    📋
TheHive integration  |   ✅   |  TBD  |   TBD
Upgrade 4→5          |   -    |  TBD  |    TBD
Agent enrollment     |   ✅   |  TBD  |   TBD
Dashboard access     |   ✅   |  TBD  |   TBD
```

### Implementation: Add Scenario Variable

```hcl
variable "test_scenario" {
  description = "Which test scenario to run"
  type        = string
  default     = "fresh_deployment"
  
  validation {
    condition = contains([
      "fresh_deployment",
      "eol_detection",
      "documentation_test",
      "thehive_integration",
      "upgrade_4_to_5",
      "agent_enrollment",
      "dashboard_access"
    ], var.test_scenario)
    error_message = "Invalid test scenario."
  }
}
```

Then in `main.tf`, conditionally deploy:

```hcl
locals {
  deploy_thehive = contains(
    ["thehive_integration"], 
    var.test_scenario
  )
  
  deploy_test_agents = contains(
    ["agent_enrollment", "eol_detection"],
    var.test_scenario
  )
}
```

---

## 5. Automated Upgrade Testing (4.14.6 → 5.0)

### Problem
- No clear migration path
- Docs will be unclear until people try it

### Solution: Upgrade Test Workflow

**New file**: `test/UPGRADE_TEST_TEMPLATE.md`

Procedure:
1. Deploy Wazuh 4.14.6 fully
2. Record: configuration, agents enrolled, indexer state
3. Run official upgrade procedure
4. Verify: agents re-enroll, data intact, dashboard accessible, rules load
5. Compare pre/post state in `Results/upgrade-report.md`

**In Terraform**: Add upgrade variable

```hcl
variable "upgrade_from_version" {
  description = "If set, deploy this version first, then upgrade to wazuh_version"
  type        = string
  default     = null  # null = fresh; "4.14.6" = deploy first, then upgrade
}
```

Script in user_data:
```bash
if [ ! -z "$UPGRADE_FROM_VERSION" ]; then
  # Deploy initial version
  # Record state
  # Run upgrade procedure
  # Verify new version
fi
```

---

## 6. Infrastructure Improvements

### A. Better Cost Tracking

**Current**: TTL defaults to 4 hours, no cost visibility

**Add to terraform outputs**:

```hcl
output "hourly_cost" {
  value = {
    server = 0.1848  # t3.xlarge on-demand
    agent  = 0.0416  # t3.xlarge on-demand
    total  = 0.2264
  }
}

output "test_cost_estimate" {
  value = "${var.resource_ttl_minutes / 60} hours = $${(var.resource_ttl_minutes / 60) * 0.2264}"
}
```

### B. Better Failure Diagnostics

Add logs collection to S3:

```bash
# In wazuh-server-init.sh
aws s3 cp /var/ossec/logs/ossec.log s3://wazuh-test-logs/${TEST_ID}/
aws s3 cp /var/log/wazuh-install.log s3://wazuh-test-logs/${TEST_ID}/
aws s3 cp /var/log/cloud-init-output.log s3://wazuh-test-logs/${TEST_ID}/
```

Then test results include S3 log URLs for debugging.

### C. Tagging for Cost Attribution

```hcl
variable "test_id" {
  description = "Unique ID for this test run"
  type        = string
  default     = "manual-${timestamp()}"
}

# In aws_instance, aws_security_group, etc:
tags = {
  TestID   = var.test_id
  Wazuh    = var.wazuh_version
  Scenario = var.test_scenario
}
```

Query AWS Cost Explorer by TestID tag.

---

## 7. Documentation Structure Improvements

### Current Organization
```
test/
├── AUTOMATED_TEST_TEMPLATE.md
├── DEPLOYMENT_RUNBOOK.md (4.14.6 only)
├── README.md
└── TTL_AND_AUTO_TERMINATION.md
```

### Improved Organization
```
test/
├── README.md (index)
├── AUTOMATED_TEST_TEMPLATE.md
├── DOCUMENTATION_TEST_TEMPLATE.md
├── UPGRADE_TEST_TEMPLATE.md
├── deployments/
│   ├── README.md (version comparison)
│   ├── wazuh_4_14_6/
│   │   ├── RUNBOOK.md
│   │   ├── known-issues.md
│   │   └── gotchas.md
│   ├── wazuh_5_0_0/
│   │   ├── RUNBOOK.md
│   │   ├── known-issues.md
│   │   └── breaking-changes.md
│   └── upgrade_4_to_5/
│       ├── RUNBOOK.md
│       └── rollback-procedure.md
└── TTL_AND_AUTO_TERMINATION.md
```

### Add to README: Version Support Matrix

```markdown
## Version Support Matrix

| Wazuh Version | Status | Test Coverage | Notes |
|---|---|---|---|
| 4.14.6 | Production | ✅ Full | Blog post EOL detector, TheHive integration |
| 5.0.0 | Beta | 📋 Partial | Fresh deploy works; upgrade path TBD |
| 5.1.0 | Planned | 🔴 None | When available |
```

---

## 8. Quick Implementation Checklist

### Phase 1: Foundation (Start immediately)
- [ ] Refactor terraform into version-specific modules
- [ ] Update README with version support matrix
- [ ] Create stub `test/deployments/wazuh_5_0_0/RUNBOOK.md`
- [ ] Add `test_scenario` variable to `terraform/variables.tf`

### Phase 2: Wazuh 5.0 Support (After Phase 1)
- [ ] Research 5.0 installation differences
- [ ] Test fresh 5.0 deploy
- [ ] Document gotchas in 5.0 runbook
- [ ] Verify all outputs match 4.14.6

### Phase 3: Test Scenarios (After Phase 2)
- [ ] Create `DOCUMENTATION_TEST_TEMPLATE.md`
- [ ] Implement scenario-driven conditionals in Terraform
- [ ] Test TheHive scenario separately

### Phase 4: Upgrade Testing (After Phase 3)
- [ ] Test 4.14.6 → 5.0 upgrade path manually
- [ ] Create `UPGRADE_TEST_TEMPLATE.md`
- [ ] Implement `upgrade_from_version` variable

### Phase 5: Polish (After Phase 4)
- [ ] Update cleanup scripts for multi-version
- [ ] Add cost tracking to outputs
- [ ] Organize docs into `deployments/` structure
- [ ] Write cross-version comparison guide

---

## Risk Mitigation

| Risk | Mitigation |
|---|---|
| 5.0 install differs significantly | Research first; prototype in separate branch |
| Modules complicate Terraform | Keep it simple: two variables, conditionals only in main.tf |
| Cost of testing 5.0 | Use 60-minute TTL for validation, extend for full tests |
| Doc testing is never-ending | Define "coverage": 10 key procedures per version |
| Breaking changes in 5.0 | Document in `breaking-changes.md` per version |

---

## Success Metrics

By end of implementation:
- ✅ Both 4.14.6 and 5.0 deployable from single repo
- ✅ Version-specific gotchas documented per version
- ✅ Test scenarios runnable: `terraform apply -var="wazuh_version=5.0.0" -var="test_scenario=thehive_integration"`
- ✅ Upgrade path documented and validated
- ✅ README clearly shows which tests are done, TBD, not applicable per version
- ✅ Cost estimates accurate and tagged by test
- ✅ Documentation testing mode available for new Wazuh releases

---

## Related Issues to Research

1. **Wazuh 5.0 Installation URL**: Is it `packages.wazuh.com/5.x/` like 4.x?
2. **API Endpoint Changes**: What's different in 5.0's API?
3. **Certificate Generation**: How does 5.0 handle SSL certs vs 4.14.6?
4. **Dashboard Auth**: Any changes to login flow or default credentials?
5. **Agent Enrollment**: Different enrollment process in 5.0?

These should be researched before Phase 2.
