# Upgrade Testing Template: 4.14.6 → 5.0.0

**Purpose**: Test the migration path from Wazuh 4.14.6 to 5.0.0. Verify service continuity, data preservation, and backward compatibility.

**When to use**:
- Planning production upgrades
- Testing upgrade procedures before deploying
- Validating agent re-enrollment after upgrade
- Verifying backup/restore workflows
- Testing rollback procedures

---

## Test Infrastructure

### Deployment

Deploy a 4.14.6 instance, upgrade to 5.0.0, then verify:

```bash
cd terraform

# Phase 1: Deploy 4.14.6 baseline (the upgrade itself is run manually over
# SSH using Wazuh's own upgrade tooling — there is no upgrade-specific
# Terraform variable; this deploys the same baseline as any other test)
terraform apply -var="wazuh_version=4.14.6"

# Save outputs
terraform output > /tmp/upgrade-baseline.txt
SERVER_DNS=$(terraform output -raw wazuh_server_public_dns)
SSH_KEY="wazuh-test-key.pem"
```

### Test Duration

| Phase | Duration | Notes |
|-------|----------|-------|
| Deploy 4.14.6 | 45 min | Initial baseline |
| Capture state | 10 min | Document pre-upgrade state |
| Upgrade process | 30 min | In-place upgrade |
| Verify services | 10 min | All services operational |
| Test re-enrollment | 15 min | Agent re-enrollment |
| Total | ~110 min | ~$0.38 cost |

---

## Phase 1: Baseline (4.14.6)

### Step 1.1: Document Pre-Upgrade State

SSH to server and capture baseline:

```bash
ssh -i $SSH_KEY ubuntu@$SERVER_DNS

# Capture version
echo "=== Current Version ===" > /tmp/upgrade-baseline.txt
sudo /var/ossec/bin/wazuh-control info >> /tmp/upgrade-baseline.txt

# Capture services
echo "" >> /tmp/upgrade-baseline.txt
echo "=== Services ===" >> /tmp/upgrade-baseline.txt
for s in wazuh-manager wazuh-indexer wazuh-dashboard; do
  sudo systemctl is-active $s >> /tmp/upgrade-baseline.txt
done

# Capture agents
echo "" >> /tmp/upgrade-baseline.txt
echo "=== Enrolled Agents ===" >> /tmp/upgrade-baseline.txt
sudo /var/ossec/bin/agent_control -l >> /tmp/upgrade-baseline.txt

# Capture config
echo "" >> /tmp/upgrade-baseline.txt
echo "=== Manager Config (first 50 lines) ===" >> /tmp/upgrade-baseline.txt
sudo head -50 /var/ossec/etc/ossec.conf >> /tmp/upgrade-baseline.txt

# Capture Indexer network config
echo "" >> /tmp/upgrade-baseline.txt
echo "=== Indexer Network Config ===" >> /tmp/upgrade-baseline.txt
sudo grep "network.host" /etc/wazuh-indexer/opensearch.yml >> /tmp/upgrade-baseline.txt

# Copy to local
cat /tmp/upgrade-baseline.txt
```

### Step 1.2: Create Test Data

Enroll an agent to create baseline data:

```bash
# Get pre-auth key (or enrollment key)
AGENT_KEY=$(sudo /var/ossec/bin/agent-auth -m $SERVER_IP -P 514)

# Note: Store this for post-upgrade verification
echo "Pre-upgrade agent enrolled with key: $AGENT_KEY"
```

---

## Phase 2: Upgrade Procedure

### Step 2.1: Backup Current Installation

**CRITICAL**: Always backup before upgrading.

```bash
ssh -i $SSH_KEY ubuntu@$SERVER_DNS

# Create backup
sudo tar -czf /root/wazuh-4.14.6-backup.tar.gz \
  /var/ossec \
  /etc/wazuh-* \
  /root/wazuh-install-files

# Verify backup size
sudo ls -lh /root/wazuh-4.14.6-backup.tar.gz

# Note: Backup takes ~2-5 minutes depending on data size
```

### Step 2.2: Download Upgrade Script

Wazuh provides version-specific upgrade paths. Get the upgrade script:

```bash
# For 5.0.0 upgrade
ssh -i $SSH_KEY ubuntu@$SERVER_DNS

# Download upgrade script from Wazuh
UPGRADE_URL="https://packages.wazuh.com/5.0/upgrade.sh"
curl -sO "$UPGRADE_URL"
chmod +x upgrade.sh

# Verify HTTP 200 (R2 rule)
curl -s -o /dev/null -w '%{http_code}' "$UPGRADE_URL"
# Expected: 200
```

### Step 2.3: Execute Upgrade

**R1 RULE**: Never trust status messages - verify with commands.

```bash
# Review upgrade script before running
less upgrade.sh

# Run upgrade (with confirmation)
sudo bash ./upgrade.sh

# Monitor progress
tail -f /var/log/wazuh-upgrade.log

# Expected output:
# - Stopping services
# - Updating packages
# - Migrating configuration
# - Restarting services
# - Upgrade complete
```

**Typical upgrade time**: 15-30 minutes

### Step 2.4: Verify Services Post-Upgrade

```bash
echo "=== Checking Services After Upgrade ===" > /tmp/upgrade-verify.txt

# Check each service (R1: actual verification)
for s in wazuh-manager wazuh-indexer wazuh-dashboard; do
  STATUS=$(sudo systemctl is-active $s 2>&1)
  if [ "$STATUS" = "active" ]; then
    echo "✓ $s is ACTIVE" >> /tmp/upgrade-verify.txt
  else
    echo "✗ $s FAILED: $STATUS" >> /tmp/upgrade-verify.txt
    sudo systemctl status $s >> /tmp/upgrade-verify.txt 2>&1
  fi
done

# Check version
echo "" >> /tmp/upgrade-verify.txt
echo "=== New Version ===" >> /tmp/upgrade-verify.txt
sudo /var/ossec/bin/wazuh-control info >> /tmp/upgrade-verify.txt

cat /tmp/upgrade-verify.txt
```

---

## Phase 3: Post-Upgrade Verification

### Step 3.1: Service Health Check

```bash
# Verify all services running
ssh -i $SSH_KEY ubuntu@$SERVER_DNS

# Verify services with actual commands (R1 rule)
for s in wazuh-manager wazuh-indexer wazuh-dashboard; do
  sudo systemctl is-active $s
done
# Expected: active (×3)

# Check Indexer connectivity
sudo curl -k -u 'admin:PASSWORD' \
  https://localhost:9200/_cluster/health \
  2>/dev/null | jq .

# Check Dashboard
curl -k -o /dev/null -w 'HTTP %{http_code}\n' https://localhost
# Expected: 302 (redirect to login) or 200 (success)
```

### Step 3.2: Agent Re-enrollment

After upgrade, agents must re-enroll:

```bash
# On agent machine
sudo /var/ossec/bin/agent-control -r

# On server, check agent appears
sudo /var/ossec/bin/agent_control -l
# Expected: Agent ID appears in list
```

### Step 3.3: Data Preservation Check

Verify data survived upgrade:

```bash
# Check if indexed data still accessible
# Example: Query for last 100 alerts
curl -k -u 'wazuh-wui:PASSWORD' \
  -X GET 'https://localhost:55000/api/alerts' \
  2>/dev/null | jq '.data | length'

# Check alert counts pre/post upgrade
# Compare with baseline from Phase 1
```

---

## Phase 4: Rollback Procedure (If Needed)

**IF UPGRADE FAILS**: Follow this rollback procedure.

### Step 4.1: Stop Services

```bash
ssh -i $SSH_KEY ubuntu@$SERVER_DNS

# Stop all Wazuh services
for s in wazuh-manager wazuh-indexer wazuh-dashboard; do
  sudo systemctl stop $s
done

# Verify stopped
for s in wazuh-manager wazuh-indexer wazuh-dashboard; do
  sudo systemctl is-active $s
done
# Expected: inactive (×3)
```

### Step 4.2: Restore from Backup

```bash
# Restore backup
sudo tar -xzf /root/wazuh-4.14.6-backup.tar.gz -C /

# Verify restoration
ls -la /var/ossec/bin/ | head -5
ls -la /etc/wazuh-* | head -5
```

### Step 4.3: Restart Services

```bash
# Restart services
for s in wazuh-manager wazuh-indexer wazuh-dashboard; do
  sudo systemctl start $s
done

# Wait for services to stabilize
sleep 10

# Verify services active
for s in wazuh-manager wazuh-indexer wazuh-dashboard; do
  sudo systemctl is-active $s
done
# Expected: active (×3)

# Verify version reverted
sudo /var/ossec/bin/wazuh-control info
# Expected: Wazuh 4.14.6
```

---

## Test Results

### Pre-Upgrade Snapshot

```
[Captured during Phase 1]
- Version: 4.14.6
- Services: manager, indexer, dashboard
- Agents enrolled: N
- Alerts indexed: M
```

### Post-Upgrade Snapshot

```
[Captured during Phase 3]
- Version: 5.0.0
- Services: manager, indexer, dashboard
- Agents re-enrolled: N
- Alerts accessible: M
```

### Test Checklist

- [ ] 4.14.6 baseline deployed successfully
- [ ] Pre-upgrade state documented
- [ ] Backup created successfully
- [ ] Upgrade script downloaded (HTTP 200)
- [ ] Upgrade process completed without errors
- [ ] All services active after upgrade
- [ ] Version shows 5.0.0
- [ ] Agents re-enrolled successfully
- [ ] Dashboard accessible post-upgrade
- [ ] API responding post-upgrade
- [ ] Agent data preserved
- [ ] Rollback procedure tested (optional)

### Test Results Output Formats

After completing the upgrade test, generate comprehensive results in **PDF** and **HTML** formats:

#### PDF Report (`upgrade-test-report.pdf`)
```
├── Executive Summary
│   ├── Overall result: PASS / PARTIAL / FAIL
│   ├── Upgrade duration: [time]
│   ├── Services status: [count] active/inactive
│   ├── Data preservation: [verification result]
│   ├── Agent re-enrollment: [count] succeeded/failed
│   └── Technical issues: [count] critical/important/minor
│
├── Technical Review
│   ├── Phase 1 Results (4.14.6 baseline)
│   │   ├── Deployment status (✅ / ❌)
│   │   ├── Pre-upgrade state snapshot
│   │   └── Services verification
│   │
│   ├── Phase 2 Results (Upgrade process)
│   │   ├── Backup created (✅ / ❌)
│   │   ├── Upgrade script validity (HTTP code)
│   │   ├── Upgrade process duration
│   │   └── Any errors encountered
│   │
│   ├── Phase 3 Results (Post-upgrade verification)
│   │   ├── Service status (✅ all active / ❌ [list failed])
│   │   ├── Version verification (5.0.0 confirmed)
│   │   ├── Agent re-enrollment success rate
│   │   ├── Data accessibility check
│   │   └── Dashboard/API functional test
│   │
│   └── Phase 4 Results (If rollback tested)
│       ├── Services stopped (✅ / ❌)
│       ├── Backup restore (✅ / ❌)
│       └── Rollback verification
│
├── Writing Quality Review (if testing documentation)
│   ├── Upgrade procedure clarity
│   ├── Prerequisite completeness
│   ├── Command formatting consistency
│   └── Expected outcome clarity
│
└── Appendix
    ├── Pre/post state comparison
    ├── Full command output logs
    └── Timestamp of test execution
```

#### HTML Report (`upgrade-test-report.html`)
```html
<interactive-dashboard>
  <status-indicators>
    <overall-result emoji="✅">PASS</overall-result>
    <services-status>manager: active, indexer: active, dashboard: active</services-status>
    <data-preservation percentage="100%">Verified</data-preservation>
    <agent-reenrollment count="1">Success</agent-reenrollment>
  </status-indicators>
  
  <timeline>
    <phase name="4.14.6 Baseline" duration="45 min" status="✅" />
    <phase name="Upgrade Process" duration="30 min" status="✅" />
    <phase name="Post-Upgrade Verification" duration="20 min" status="✅" />
    <phase name="Data Preservation Check" duration="10 min" status="✅" />
  </timeline>
  
  <detailed-results collapsible="true">
    <section id="pre-upgrade-state">
      <h3>Pre-Upgrade State Snapshot</h3>
      <code-block language="text">Version: 4.14.6, Services: [list], Agents: [count]</code-block>
    </section>
    
    <section id="post-upgrade-state">
      <h3>Post-Upgrade State Snapshot</h3>
      <code-block language="text">Version: 5.0.0, Services: [list], Agents: [count]</code-block>
    </section>
  </detailed-results>
</interactive-dashboard>
```

### Issues Encountered

| Issue | Severity | Resolution | Verified |
|-------|----------|-----------|----------|
| [Issue name] | Critical/Important/Minor | [How fixed] | [ ] |

### Recommendations

- [ ] Upgrade safe for production
- [ ] Documentation needs update
- [ ] Agent re-enrollment procedure needs clarification
- [ ] Backup/restore procedure works
- [ ] Rollback procedure works

---

## Comparison: What Changed in 5.0.0

**Quick reference** (capture the detailed pre/post analysis in this test's
`results/` report rather than a permanent comparison doc — there's no
`terraform/versions/` split in the current baseline to hang one off):
- Installation method: Same (quickstart installer)
- Services: Same (manager, indexer, dashboard)
- Ports: Same (55000 for API, 9200 for Indexer)
- Credentials: Format unchanged, still in tar file
- Agent enrollment: Expected same (verify during testing)
- API endpoints: TBD (needs verification)

---

## Cost Tracking

| Phase | Resource | Duration | Cost |
|-------|----------|----------|------|
| Deploy 4.14.6 | t3.xlarge | 45 min | ~$0.21 |
| Upgrade | t3.xlarge | 30 min | ~$0.14 |
| Verification | t3.xlarge | 20 min | ~$0.09 |
| **Total** | | ~110 min | ~$0.44 |

---

## Related Documentation

- [TEST_SCENARIOS_GUIDE.md](TEST_SCENARIOS_GUIDE.md) - Scenario overview
- [DOCUMENTATION_TEST_TEMPLATE.md](DOCUMENTATION_TEST_TEMPLATE.md) - Doc validation
- [test/deployments/wazuh_5_0_0/RUNBOOK.md](deployments/wazuh_5_0_0/RUNBOOK.md) - 5.0.0 deployment details

---

**Template Version**: Phase 4  
**Last Updated**: 2026-07-29  
**Status**: Ready for testing phase
