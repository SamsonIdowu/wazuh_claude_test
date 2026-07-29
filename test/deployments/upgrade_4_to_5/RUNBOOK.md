# Upgrade 4.14.6 → 5.0.0 Testing Runbook

**Status:** 📋 PHASE 4 READY — Infrastructure code and procedures ready

This runbook documents the upgrade testing scenario. It combines the baseline 4.14.6 deployment with the 5.0.0 upgrade path for comprehensive migration testing.

---

## Overview

The `upgrade_4_to_5` scenario deploys:
1. Wazuh 4.14.6 server (baseline)
2. Wazuh agent (for testing re-enrollment)
3. All supporting infrastructure (security groups, networking)

After deployment, you manually upgrade the server to 5.0.0 and verify compatibility.

---

## Scenario Purpose

**Goal**: Test the 4.14.6 → 5.0.0 upgrade path in a controlled environment before production upgrades.

**Key outcomes**:
- ✅ Upgrade procedure documented and verified
- ✅ Service continuity confirmed (no downtime)
- ✅ Data preservation validated
- ✅ Agent re-enrollment successful
- ✅ Rollback procedure tested

---

## Deployment

### Prerequisites

```bash
cd terraform

# Verify variables configured
terraform validate

# Check terraform.tfvars or set inline
terraform apply -var-file="terraform.tfvars" -var="wazuh_version=4.14.6"
```

### What Gets Deployed

| Component | Count | Details |
|-----------|-------|---------|
| **EC2 Instances** | 1 | t3.xlarge, Ubuntu 22.04 |
| **Wazuh Server** | 1 | 4.14.6 (baseline) |
| **Wazuh Agent** | 1 | Enrolled to server |
| **Security Groups** | 1 | All required ports |
| **Volume** | 1 | 30GB gp3 EBS |
| **Network** | VPC | Public subnets |

### Timeline

| Phase | Duration | Notes |
|-------|----------|-------|
| Infrastructure | 2-3 min | EC2 provisioning |
| Installation | 30 min | Wazuh 4.14.6 quickstart |
| Agent enrollment | 5 min | Pre-auth key enrollment |
| **Total deployment** | ~40 min | Ready for upgrade |

### Cost

- Baseline deployment: ~$0.19 (1 instance, 45 min)
- Upgrade testing: ~$0.14 (30 min additional)
- Total scenario: ~$0.38 (1.5 hours)

---

## Test Procedure

### Phase 1: Baseline Verification

After deployment completes:

```bash
# Get server details
terraform output
SERVER_DNS=$(terraform output -raw wazuh_server_public_dns)
SSH_KEY="wazuh-test-key.pem"

# SSH to server
ssh -i $SSH_KEY ubuntu@$SERVER_DNS

# Verify 4.14.6 is running
sudo /var/ossec/bin/wazuh-control info
# Expected: Manager 4.14.6

# Verify services
for s in wazuh-manager wazuh-indexer wazuh-dashboard; do
  sudo systemctl is-active $s
done
# Expected: active (×3)

# Verify agent enrolled
sudo /var/ossec/bin/agent_control -l
# Expected: agent ID listed

# Document state
echo "=== BASELINE STATE ===" > /tmp/baseline.txt
sudo /var/ossec/bin/wazuh-control info >> /tmp/baseline.txt
sudo /var/ossec/bin/agent_control -l >> /tmp/baseline.txt
cat /tmp/baseline.txt
```

### Phase 2: Create Backup

**CRITICAL**: Always backup before upgrading.

```bash
ssh -i $SSH_KEY ubuntu@$SERVER_DNS

# Create full backup
sudo tar -czf /root/wazuh-4.14.6-backup.tar.gz \
  /var/ossec \
  /etc/wazuh-indexer \
  /etc/wazuh-manager \
  /etc/wazuh-dashboard \
  /root/wazuh-install-files

# Verify backup
sudo ls -lh /root/wazuh-4.14.6-backup.tar.gz
# Expected: Size > 100MB (contains installed Wazuh + data)
```

### Phase 3: Upgrade to 5.0.0

**R2 Rule**: Verify URL before piping to shell.

```bash
ssh -i $SSH_KEY ubuntu@$SERVER_DNS

# Download upgrade script
UPGRADE_SCRIPT="wazuh-upgrade.sh"
curl -sO "https://packages.wazuh.com/5.0/${UPGRADE_SCRIPT}"

# Verify HTTP 200
curl -s -o /dev/null -w '%{http_code}' \
  "https://packages.wazuh.com/5.0/${UPGRADE_SCRIPT}"
# Expected: 200

# Review script
less "$UPGRADE_SCRIPT"

# Run upgrade (prepare for ~15-30 minutes)
sudo bash "./${UPGRADE_SCRIPT}"

# Monitor progress
tail -f /var/log/wazuh-upgrade.log
```

**What happens**:
1. Services stop
2. Packages updated
3. Configuration migrated
4. Services restart
5. Verification runs

### Phase 4: Post-Upgrade Verification

```bash
ssh -i $SSH_KEY ubuntu@$SERVER_DNS

# Check version
sudo /var/ossec/bin/wazuh-control info
# Expected: Manager 5.0.0

# Verify all services active
for s in wazuh-manager wazuh-indexer wazuh-dashboard; do
  STATUS=$(sudo systemctl is-active $s)
  echo "$s: $STATUS"
done
# Expected: active (×3)

# Verify agent still connected
sudo /var/ossec/bin/agent_control -l
# Expected: agent ID still listed

# Check agent connection status
sudo /var/ossec/bin/agent_control -i <AGENT_ID>
# Expected: Connected

# Verify Indexer network config
sudo grep "network.host" /etc/wazuh-indexer/opensearch.yml
# Expected: 0.0.0.0 or unchanged
```

### Phase 5: Agent Re-enrollment

If agent fails to reconnect automatically:

```bash
# On agent machine (or via agent SSH)
sudo /var/ossec/bin/agent-control -r

# Monitor agent logs
sudo tail -f /var/ossec/logs/ossec.log | grep -i "connect"

# On server, verify agent status
sudo /var/ossec/bin/agent_control -l
# Expected: Agent appears with "Connected" status

# If agent still not connecting:
# Option 1: Restart agent
sudo systemctl restart wazuh-agent

# Option 2: Force re-enrollment
sudo rm -f /var/ossec/etc/client.keys
sudo /var/ossec/bin/agent-auth -m <SERVER_IP> -P 514
```

### Phase 6: Data Preservation Check

Verify indexed data survived upgrade:

```bash
# Get wazuh-wui credentials
sudo tar -xOf /root/wazuh-install-files.tar \
  wazuh-install-files/wazuh-passwords.txt | grep "wazuh-wui"

# Test API access
WUI_PASSWORD="<PASSWORD_FROM_ABOVE>"
curl -k -u 'wazuh-wui:'"$WUI_PASSWORD" \
  -X GET 'https://localhost:55000/api/version'

# Check recent alerts (R1: verify with functional query)
curl -k -u 'wazuh-wui:'"$WUI_PASSWORD" \
  -X GET 'https://localhost:55000/api/alerts?limit=5'

# Expected: JSON response with alerts
```

---

## Rollback Procedure

If upgrade fails critically:

```bash
ssh -i $SSH_KEY ubuntu@$SERVER_DNS

# Step 1: Stop services
for s in wazuh-manager wazuh-indexer wazuh-dashboard; do
  sudo systemctl stop $s
done

# Step 2: Remove upgraded packages
sudo apt-get remove -y wazuh-manager wazuh-indexer wazuh-dashboard

# Step 3: Restore backup
sudo tar -xzf /root/wazuh-4.14.6-backup.tar.gz -C /

# Step 4: Restart services
for s in wazuh-manager wazuh-indexer wazuh-dashboard; do
  sudo systemctl start $s
done

# Step 5: Verify restored
sudo /var/ossec/bin/wazuh-control info
# Expected: Manager 4.14.6
```

---

## Expected Issues & Workarounds

### Issue 1: Indexer Connection Loss After Upgrade

**Symptom**: Dashboard shows "Indexer unreachable"

**Cause**: Network binding issue during upgrade

**Workaround**:
```bash
# Check current binding
sudo grep "network.host" /etc/wazuh-indexer/opensearch.yml

# If localhost-only, fix it
sudo sed -i 's|^network.host: .*|network.host: "0.0.0.0"|' \
  /etc/wazuh-indexer/opensearch.yml

# Restart Indexer
sudo systemctl restart wazuh-indexer
sleep 5

# Verify
sudo systemctl is-active wazuh-indexer
```

### Issue 2: Agent Cannot Re-enroll After Upgrade

**Symptom**: Agent shows "Disconnected" status

**Cause**: Agent config may need update or key regeneration

**Workaround**:
```bash
# On server: Generate new enrollment
sudo /var/ossec/bin/agent-auth -m 0.0.0.0 -P 514 -g -i 99

# On agent: Stop and reset
sudo systemctl stop wazuh-agent
sudo rm -f /var/ossec/etc/client.keys
sudo systemctl start wazuh-agent

# Monitor reconnection
sudo tail -f /var/ossec/logs/ossec.log | grep -i "enrollment\|connected"
```

### Issue 3: API Endpoint Changes in 5.0.0

**Symptom**: API calls return 404

**Cause**: Endpoint paths may have changed

**Workaround**:
```bash
# Get current API version
curl -k -u 'wazuh-wui:PASSWORD' \
  https://localhost:55000/api/version

# Check endpoint availability
curl -k -u 'wazuh-wui:PASSWORD' \
  https://localhost:55000/api/agents

# If endpoint fails, check documentation
# https://docs.wazuh.com/5.0/api/
```

---

## Verification Checklist

- [ ] Deployment successful (4.14.6 running)
- [ ] Baseline state documented
- [ ] Backup created and verified
- [ ] Upgrade script downloaded (HTTP 200)
- [ ] Upgrade process completed
- [ ] Version shows 5.0.0
- [ ] All services active post-upgrade
- [ ] Agent re-enrolled or reconnected
- [ ] Dashboard accessible
- [ ] API responding
- [ ] Alerts indexed post-upgrade
- [ ] Rollback tested (optional)

---

## Test Results Template

```
UPGRADE TEST RESULTS
════════════════════════════════════════════

Deployment: [Date]
Tester: [Name]

BASELINE (4.14.6)
─────────────────
Version: 4.14.6.xxx
Services: [active/inactive]
Agents: [count]
Alerts: [count]

UPGRADE PROCESS
───────────────
Start time: [time]
End time: [time]
Duration: [minutes]
Status: [success/failure]
Errors: [list any]

POST-UPGRADE (5.0.0)
────────────────────
Version: 5.0.0.xxx
Services: [active/inactive]
Agents: [count, re-enrolled/connected]
Alerts: [count, preserved/loss]

ISSUES ENCOUNTERED
──────────────────
[Issue 1]: [Resolved/Escalated]
[Issue 2]: [Resolved/Escalated]

ROLLBACK TESTED
───────────────
[Yes/No]: [Successful/Failed]

RECOMMENDATION
───────────────
Ready for production: [Yes/No]
Next steps: [List any]
```

---

## Cost Summary

| Component | Cost | Duration |
|-----------|------|----------|
| 4.14.6 baseline | $0.19 | 45 min |
| Upgrade testing | $0.14 | 30 min |
| Verification | $0.05 | 10 min |
| **Total** | **$0.38** | **~90 min** |

---

## Related Documentation

- [UPGRADE_TEST_TEMPLATE.md](../UPGRADE_TEST_TEMPLATE.md) - Step-by-step testing procedure
- [TEST_SCENARIOS_GUIDE.md](../TEST_SCENARIOS_GUIDE.md) - Scenario overview
- [test/deployments/wazuh_5_0_0/RUNBOOK.md](../wazuh_5_0_0/RUNBOOK.md) - 5.0.0 deployment details

---

**Last Updated**: Phase 4 (2026-07-29)  
**Status**: 📋 Ready for testing — awaiting first upgrade attempt
