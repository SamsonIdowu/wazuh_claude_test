# Test Scenarios Guide

This guide explains how to use the test scenario system to deploy Wazuh infrastructure configured for specific testing purposes.

---

## Overview

The `test_scenario` variable controls what infrastructure gets deployed. Each scenario deploys only the resources needed for that specific test, reducing cost and complexity.

```bash
terraform apply -var="test_scenario=fresh_deployment"  # Default: basic server + agent
terraform apply -var="test_scenario=eol_detection"     # EOL detection blog post test
terraform apply -var="test_scenario=documentation_test" # Validate docs against live infra
terraform apply -var="test_scenario=thehive_integration"# Server + agent + TheHive
terraform apply -var="test_scenario=dashboard_access"   # UI/UX testing
terraform apply -var="test_scenario=agent_enrollment"   # Agent enrollment flow
terraform apply -var="test_scenario=upgrade_4_to_5"     # Version upgrade path
```

---

## Available Scenarios

### 1. fresh_deployment (Default)

**Purpose**: Baseline validation. Verify Wazuh server and agent deploy correctly.

**What gets deployed**:
- Wazuh server (manager + indexer + dashboard)
- Wazuh agent (enrolled to server)
- Security groups configured for basic access

**Use when**:
- Testing new Wazuh version
- Validating infrastructure code
- Establishing baseline functionality

**Typical test duration**: 45 minutes

**Cost**: ~$0.21 (1 hour)

**Verification checklist**:
```bash
# SSH to server
ssh -i wazuh-test-key.pem ubuntu@<server_dns>

# Check services
sudo systemctl status wazuh-manager wazuh-indexer wazuh-dashboard

# Check agent
sudo /var/ossec/bin/agent_control -l

# Test dashboard
curl -k https://localhost
```

---

### 2. eol_detection

**Purpose**: Test EOL detection implementation from blog post.

**What gets deployed**:
- Wazuh server (full stack)
- Wazuh agent (for testing EOL detector)
- Security groups for blog post requirements

**Use when**:
- Testing end-of-life software detection
- Validating EOL detector Python script
- Running blog post implementation tests

**Typical test duration**: 60 minutes (45 min deploy + 15 min tests)

**Cost**: ~$0.32 (1.5 hours with testing)

**Verification checklist**:
```bash
# Deploy EOL detector script
scp -i wazuh-test-key.pem eol_detector.py \
  ubuntu@<server_dns>:/tmp/

# SSH and configure
ssh -i wazuh-test-key.pem ubuntu@<server_dns>
sudo cp /tmp/eol_detector.py /var/ossec/integrations/
sudo chown wazuh:wazuh /var/ossec/integrations/eol_detector.py
sudo chmod 750 /var/ossec/integrations/eol_detector.py

# Test manually
sudo python3 /var/ossec/integrations/eol_detector.py

# Verify output
sudo tail /var/ossec/logs/eol-findings/eol.json
```

---

### 3. documentation_test

**Purpose**: Validate official Wazuh documentation against live deployment.

**What gets deployed**:
- Wazuh server with all features enabled
- Agent (for procedure testing)
- All security groups (for completeness)

**Use when**:
- Testing new documentation
- Verifying procedures are accurate
- Identifying outdated information
- Capturing actual UI/API behavior

**Typical test duration**: 60-120 minutes (testing + documentation)

**Cost**: ~$0.42-0.84 (1-2 hours)

**Verification checklist**:
Use the [DOCUMENTATION_TEST_TEMPLATE.md](DOCUMENTATION_TEST_TEMPLATE.md)

---

### 4. thehive_integration

**Purpose**: Test Wazuh ↔ TheHive integration.

**What gets deployed**:
- Wazuh server (full stack)
- TheHive instance (5.x)
- Agent (for alert generation)
- Security groups for TheHive communication

**Use when**:
- Testing Wazuh-to-TheHive alert forwarding
- Validating SOAR integration
- Testing alert enrichment

**Typical test duration**: 90 minutes (60 min deploy + 30 min testing)

**Cost**: ~$0.53 (1.5 hours)

**Note**: TheHive deployment adds infrastructure; see TheHive runbook for details.

---

### 5. dashboard_access

**Purpose**: UI/UX testing and dashboard feature validation.

**What gets deployed**:
- Wazuh server (with dashboard enabled)
- Agent (to generate data for dashboard)
- Security groups optimized for web access

**Use when**:
- Testing dashboard UI elements
- Validating new dashboard features
- Screenshot/documentation capture
- Usability testing

**Typical test duration**: 45 minutes

**Cost**: ~$0.21 (1 hour)

**Verification checklist**:
```bash
# Get credentials
terraform output | grep dashboard

# Access dashboard
# Open in browser: https://<server_dns>
# Login: admin / <password>

# Verify features
- [ ] Main dashboard visible
- [ ] Agent data appears
- [ ] Can view modules
- [ ] Can view alerts
- [ ] Can navigate settings
```

---

### 6. agent_enrollment

**Purpose**: Test agent enrollment and communication flow.

**What gets deployed**:
- Wazuh server (manager only, minimal indexer/dashboard)
- Multiple agents for enrollment testing
- Network optimized for agent communication

**Use when**:
- Testing agent enrollment protocol
- Validating agent-server communication
- Testing pre-auth keys
- Network configuration testing

**Typical test duration**: 45 minutes

**Cost**: ~$0.21 (1 hour)

**Verification checklist**:
```bash
# SSH to server
ssh -i wazuh-test-key.pem ubuntu@<server_dns>

# View agents
sudo /var/ossec/bin/agent_control -l

# Check agent status
sudo /var/ossec/bin/agent_control -i <agent_id>

# View agent logs
sudo tail /var/ossec/logs/agent.log
```

---

### 7. upgrade_4_to_5 (Phase 4)

**Purpose**: Test 4.14.6 → 5.0.0 migration.

**What gets deployed** (when implemented):
- Wazuh 4.14.6 server (baseline)
- Wazuh agent (to test re-enrollment)
- Security groups for upgrade scenario

**Use when**:
- Planning to upgrade production
- Testing upgrade procedures
- Validating backward compatibility

**Typical test duration**: 120 minutes (45 min 4.14.6 + 45 min 5.0 + 30 min testing)

**Cost**: ~$0.42 (1.5 hours)

**Note**: This scenario will be fully implemented in Phase 4.

---

## How to Use Scenarios

### Command Line

```bash
# Using variable flag
terraform apply -var="test_scenario=eol_detection"

# Using terraform.tfvars
echo 'test_scenario = "documentation_test"' >> terraform/terraform.tfvars
terraform apply
```

### With Version Selection

```bash
# Test EOL detection on Wazuh 5.0
terraform apply \
  -var="wazuh_major_version=5" \
  -var="test_scenario=eol_detection"

# Test documentation on Wazuh 4.14.6
terraform apply \
  -var="wazuh_major_version=4" \
  -var="test_scenario=documentation_test"
```

### With Custom TTL

```bash
# Extended testing window
terraform apply \
  -var="test_scenario=documentation_test" \
  -var="resource_ttl_minutes=480"  # 8 hours
```

---

## Scenario Comparison Matrix

| Scenario | Services | Agent | TheHive | Duration | Cost | Use Case |
|----------|----------|-------|---------|----------|------|----------|
| fresh_deployment | Server | Yes | No | 45 min | $0.21 | Baseline validation |
| eol_detection | Server | Yes | No | 60 min | $0.32 | Blog post test |
| documentation_test | Server | Yes | No | 60-120 min | $0.42-0.84 | Validate docs |
| thehive_integration | Server | Yes | **Yes** | 90 min | $0.53 | SOAR integration |
| dashboard_access | Server | Yes | No | 45 min | $0.21 | UI/UX testing |
| agent_enrollment | Server | Multiple | No | 45 min | $0.21 | Agent protocol |
| upgrade_4_to_5 | Both | Yes | No | 120 min | $0.42 | Migration testing |

---

## Verification Strategy

Each scenario has:

1. **Deployment verification** - Confirm infrastructure deployed correctly
2. **Service verification** - Confirm services are running (R1 rule: verify with command)
3. **Functional verification** - Confirm the feature works as expected
4. **Documentation** - Capture findings in Results/ directory

---

## Extending Scenarios

To add a new scenario:

1. Add it to the `test_scenario` variable validation in `terraform/variables.tf`
2. Document it in this guide
3. Add conditional deployment logic in Terraform (coming in Phase 3 complete)
4. Create a test template for the new scenario

Example:
```hcl
variable "test_scenario" {
  validation {
    condition = contains([
      "fresh_deployment",
      "eol_detection",
      "documentation_test",
      "thehive_integration",
      "dashboard_access",
      "agent_enrollment",
      "upgrade_4_to_5",
      "custom_scenario_name"  # New scenario here
    ], var.test_scenario)
  }
}
```

---

## Cost Optimization

- Scenarios run with 1-hour default TTL (~$0.21 base cost)
- Extend TTL only if testing takes longer
- Cleanup automatically when TTL expires
- No cost if resources are not deployed
- Use manual `terraform destroy` to cleanup immediately

---

## Next: Phase 3 Complete

After Phase 3:
- All 7 scenarios defined
- Test templates for each scenario
- Verification procedures documented
- Ready for Phase 4 (upgrade testing)

---

**Version**: Phase 3 Draft  
**Last Updated**: 2026-07-29  
**Status**: Template ready, implementation coming
