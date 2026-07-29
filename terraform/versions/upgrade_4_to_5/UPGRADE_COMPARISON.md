# Upgrade Path: 4.14.6 → 5.0.0 Analysis

This document captures what changes during the 4.14.6 → 5.0.0 upgrade and how to verify each change.

---

## Service Changes

| Service | 4.14.6 | 5.0.0 | Change | Verification |
|---------|--------|-------|--------|--------------|
| wazuh-manager | Running | Running | ✓ Continues | `systemctl is-active wazuh-manager` |
| wazuh-indexer | Running | Running | ✓ Continues | `systemctl is-active wazuh-indexer` |
| wazuh-dashboard | Running | Running | ✓ Continues | `systemctl is-active wazuh-dashboard` |

**Expected behavior**: All services should remain active throughout the upgrade. Brief restart (~1 min each) is normal.

---

## Data Persistence

| Data | 4.14.6 | 5.0.0 | Change | Risk |
|------|--------|-------|--------|------|
| **Indexed alerts** | OpenSearch | OpenSearch | ✓ Same store | Low - automatic migration |
| **Agent data** | Local files | Local files | ✓ Same location | Low - config preserved |
| **Certificates** | /var/ossec/etc/ | /var/ossec/etc/ | ✓ Preserved | Low - not regenerated |
| **Manager config** | ossec.conf | ossec.conf | ⚠️ Possible changes | Medium - verify syntax |
| **Agent keys** | client.keys | client.keys | ✓ Preserved | Low - agents reconnect |

**Expected behavior**: All data should survive the upgrade. Agents may need brief re-connection time.

---

## Configuration Changes

### Manager Configuration (ossec.conf)

**Expected changes** (typical major-version upgrade):
- New XML elements may be added with defaults
- Some old elements may be deprecated but retained
- Port numbers should remain the same

```bash
# Backup pre-upgrade
sudo cp /var/ossec/etc/ossec.conf /tmp/ossec.conf.4.14.6

# Compare post-upgrade
sudo diff /tmp/ossec.conf.4.14.6 /var/ossec/etc/ossec.conf

# Expected differences:
# - New <integration> blocks
# - Updated <decoders> references
# - Modified log ingestion rules
```

### Indexer Configuration

**Potential issue**: Localhost binding (same as 4.14.6)

```bash
# Check binding pre-upgrade
sudo grep "network.host" /etc/wazuh-indexer/opensearch.yml
# Expected: "127.0.0.1" or "0.0.0.0"

# If still localhost after upgrade:
sudo sed -i 's|^network.host: .*|network.host: "0.0.0.0"|' \
  /etc/wazuh-indexer/opensearch.yml
sudo systemctl restart wazuh-indexer
```

### Dashboard Configuration

Dashboard config should remain compatible. Check access:

```bash
# Test dashboard
curl -k -u 'admin:PASSWORD' \
  https://localhost/app/wazuh
# Expected: 200 (or redirect if not authenticated)
```

---

## API Changes

**Status**: ⚠️ NEEDS VERIFICATION

Expected (based on major-version patterns):
- Base endpoint `/api` remains same
- Authentication method unchanged (JWT)
- Response formats may have minor changes
- New endpoints likely added, old ones kept

### Verify API Compatibility

```bash
# Get wazuh-wui credentials
WUI_PASS=$(sudo tar -xOf /root/wazuh-install-files.tar \
  wazuh-install-files/wazuh-passwords.txt | grep "wazuh-wui:" | cut -d: -f2)

# Test authentication (key endpoint)
curl -k -u 'wazuh-wui:'"$WUI_PASS" \
  -X POST 'https://localhost:55000/security/user/authenticate' \
  -H 'Content-Type: application/json' \
  -d '{}'
# Expected: JSON with JWT token

# Test agents endpoint
curl -k -u 'wazuh-wui:'"$WUI_PASS" \
  'https://localhost:55000/api/agents' \
  -H 'Authorization: Bearer <JWT_TOKEN>'
# Expected: 200 with agent list

# Test version endpoint
curl -k -u 'wazuh-wui:'"$WUI_PASS" \
  'https://localhost:55000/api/version'
# Expected: JSON with version info
```

---

## Agent Compatibility

**Critical**: Agents from 4.14.6 must reconnect after server upgrade to 5.0.0.

### Agent Enrollment

| Phase | Behavior | Verification |
|-------|----------|--------------|
| **Pre-upgrade** | Agents connected to 4.14.6 | `agent_control -l` shows Connected |
| **During upgrade** | Agent connection may drop (normal) | Agent logs show disconnect/reconnect |
| **Post-upgrade** | Agent re-enrolls automatically or manually | `agent_control -l` shows Connected |

### Verify Agent Re-enrollment

```bash
# On server after upgrade
sudo /var/ossec/bin/agent_control -l
# Expected: All agents show "Connected"

# If agent still disconnected:
sudo /var/ossec/bin/agent_control -i <AGENT_ID>
# Check status field

# Force re-enrollment (if needed)
sudo /var/ossec/bin/agent-control -r  # On agent machine
```

---

## Known Issues to Watch For

### Issue 1: API Endpoint Changes

**Risk**: Medium  
**Symptom**: API calls return 404  
**Workaround**: Check Wazuh 5.0 API docs, update endpoints

```bash
# If endpoints changed, check logs
sudo tail /var/ossec/logs/api.log

# Compare with 4.14.6 API docs
# https://docs.wazuh.com/5.0/api/
```

### Issue 2: Agent Enrollment Incompatibility

**Risk**: Low (usually backward compatible)  
**Symptom**: Agents show "Disconnected"  
**Workaround**: Restart agent or re-enroll with new key

### Issue 3: Indexer Network Binding

**Risk**: Medium  
**Symptom**: Dashboard shows "Indexer unreachable"  
**Workaround**: Edit opensearch.yml and restart indexer

### Issue 4: Log Format Changes

**Risk**: Low (usually backward compatible)  
**Symptom**: Custom log parsing breaks  
**Workaround**: Update log parsing rules to handle 5.0 format

---

## Rollback Procedures

If upgrade fails, rollback is straightforward:

```bash
# 1. Stop services
for s in wazuh-manager wazuh-indexer wazuh-dashboard; do
  sudo systemctl stop $s
done

# 2. Restore from backup
sudo tar -xzf /root/wazuh-4.14.6-backup.tar.gz -C /

# 3. Restart services
for s in wazuh-manager wazuh-indexer wazuh-dashboard; do
  sudo systemctl start $s
done

# 4. Verify
sudo /var/ossec/bin/wazuh-control info
# Expected: Manager 4.14.6
```

**Time to rollback**: ~5-10 minutes

---

## Upgrade Timeline

| Phase | Duration | What Happens |
|-------|----------|--------------|
| **Pre-upgrade** | - | System running normally |
| **Backup** | 5 min | Create backup tar file |
| **Stop services** | 1 min | Manager, indexer, dashboard stop |
| **Update packages** | 10 min | apt-get pulls new versions |
| **Migrate config** | 5 min | Config files updated, new defaults applied |
| **Restart services** | 5 min | Services start in order |
| **Verify** | 2 min | Health checks run |
| **Indexer stabilize** | 5 min | Wait for indexer to be fully responsive |
| **Total** | ~35 min | Full upgrade window |

**Important**: Dashboard/API may be briefly unavailable during restart phase.

---

## Pre-Upgrade Checklist

Before starting upgrade:

- [ ] Backup created and verified
- [ ] Disk space available (at least 5GB free)
- [ ] No active alerts/integrations running
- [ ] Agent policy updates complete
- [ ] Maintenance window scheduled (users notified)
- [ ] Rollback plan documented

---

## Post-Upgrade Verification

After upgrade completes:

- [ ] All services active
- [ ] Dashboard accessible
- [ ] API responding
- [ ] Agents reconnecting or re-enrolled
- [ ] Indexed alerts accessible
- [ ] No errors in logs
- [ ] Certificates valid
- [ ] Network connectivity stable

---

## Testing Commands Summary

### Pre-Upgrade Snapshot

```bash
# Capture baseline
echo "=== Pre-Upgrade State ===" > /tmp/upgrade-check.txt

echo "" >> /tmp/upgrade-check.txt
echo "Version:" >> /tmp/upgrade-check.txt
sudo /var/ossec/bin/wazuh-control info >> /tmp/upgrade-check.txt

echo "" >> /tmp/upgrade-check.txt
echo "Services:" >> /tmp/upgrade-check.txt
systemctl status wazuh-* >> /tmp/upgrade-check.txt

echo "" >> /tmp/upgrade-check.txt
echo "Agents:" >> /tmp/upgrade-check.txt
sudo /var/ossec/bin/agent_control -l >> /tmp/upgrade-check.txt

cat /tmp/upgrade-check.txt
```

### Post-Upgrade Snapshot

```bash
# Capture result
echo "=== Post-Upgrade State ===" > /tmp/upgrade-result.txt

echo "" >> /tmp/upgrade-result.txt
echo "Version:" >> /tmp/upgrade-result.txt
sudo /var/ossec/bin/wazuh-control info >> /tmp/upgrade-result.txt

echo "" >> /tmp/upgrade-result.txt
echo "Services:" >> /tmp/upgrade-result.txt
systemctl status wazuh-* >> /tmp/upgrade-result.txt

echo "" >> /tmp/upgrade-result.txt
echo "Agents:" >> /tmp/upgrade-result.txt
sudo /var/ossec/bin/agent_control -l >> /tmp/upgrade-result.txt

echo "" >> /tmp/upgrade-result.txt
echo "API Test:" >> /tmp/upgrade-result.txt
curl -k -u 'wazuh-wui:PASSWORD' \
  'https://localhost:55000/api/version' 2>/dev/null >> /tmp/upgrade-result.txt

cat /tmp/upgrade-result.txt
```

---

## Related Documentation

- [test/UPGRADE_TEST_TEMPLATE.md](../../test/UPGRADE_TEST_TEMPLATE.md) - Detailed testing procedure
- [test/deployments/upgrade_4_to_5/RUNBOOK.md](../../test/deployments/upgrade_4_to_5/RUNBOOK.md) - Upgrade scenario runbook
- [terraform/versions/v5_0_0/COMPARISON.md](../v5_0_0/COMPARISON.md) - 4.14.6 vs 5.0.0 feature comparison

---

**Last Updated**: Phase 4 (2026-07-29)  
**Status**: 📋 Ready for upgrade testing
