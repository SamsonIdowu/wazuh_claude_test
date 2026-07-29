# Wazuh 4.14.6 vs 5.0.0 Deployment Comparison

This document captures the differences between Wazuh 4.14.6 and 5.0.0 deployments based on Phase 2 research and testing.

---

## Installation Procedure

| Aspect | 4.14.6 | 5.0.0 | Notes |
|--------|--------|-------|-------|
| **Installer URL** | `/4.14/wazuh-install.sh` | `/5.0/wazuh-install.sh` | ✓ URL format consistent |
| **Installer flags** | `-a -i` | `-a -i` | ✓ Same flags work |
| **Installation time** | ~30 minutes | ~30 minutes | ✓ Estimated same |
| **Method** | Quickstart installer | Quickstart installer | ✓ No change |
| **Curl verification** | Required (silent 403 failure) | Required (silent 403 failure) | ✓ Same risk |

---

## Services & Components

| Component | 4.14.6 | 5.0.0 | Notes |
|-----------|--------|-------|-------|
| **Manager** | wazuh-manager | wazuh-manager | ✓ Same |
| **Indexer** | wazuh-indexer (OpenSearch) | wazuh-indexer (OpenSearch) | ✓ Same |
| **Dashboard** | wazuh-dashboard | wazuh-dashboard | ✓ Same |
| **All running** | systemctl is-active | systemctl is-active | ✓ Same check |

---

## Credentials & Access

| Aspect | 4.14.6 | 5.0.0 | Notes |
|--------|--------|-------|-------|
| **Credentials** | Random (not admin/admin) | Random (not admin/admin) | ✓ Same |
| **Retrieval** | `tar -xOf /root/wazuh-install-files.tar` | `tar -xOf /root/wazuh-install-files.tar` | ✓ Same |
| **Accounts** | admin, wazuh-wui | admin, wazuh-wui | ✓ Same |
| **Dashboard port** | 443 (HTTPS) | 443 (HTTPS) | ✓ Same |
| **API port** | 55000 | 55000 | ✓ Same |

---

## Indexer Configuration

| Aspect | 4.14.6 | 5.0.0 | Notes |
|--------|--------|-------|-------|
| **Localhost binding issue** | **YES** (confirmed) | **?** (TBD) | ⚠️ Test during Phase 2 |
| **Config file** | `/etc/wazuh-indexer/opensearch.yml` | `/etc/wazuh-indexer/opensearch.yml` | ✓ Same |
| **Fix** | `network.host: "0.0.0.0"` | `network.host: "0.0.0.0"` | ✓ Same workaround |
| **Port** | 9200 | 9200 | ✓ Same |

**Action**: Script includes 4.14.6 workaround; will observe if needed in 5.0.0.

---

## API Differences

| Aspect | 4.14.6 | 5.0.0 | Notes |
|--------|--------|-------|-------|
| **Base endpoint** | `/api` | `/api` | ✓ Assume same |
| **Authentication** | JWT via `/security/user/authenticate` | ? | ⚠️ TBD - verify endpoint |
| **Response format** | JSON | ? | ⚠️ TBD - check for changes |
| **Agent endpoints** | `/agents`, `/agents/groups` | ? | ⚠️ TBD - check for changes |

**Action**: During testing, verify:
  1. JWT authentication still works
  2. Agent enrollment still uses same protocol
  3. API response formats unchanged

---

## Agent Enrollment

| Aspect | 4.14.6 | 5.0.0 | Notes |
|--------|--------|-------|-------|
| **Agent port** | 1514 (TCP/UDP) | 1514 (TCP/UDP) | ✓ Assume same |
| **Enrollment method** | Pre-authorization or manual | ? | ⚠️ TBD |
| **Agent config** | `/var/ossec/etc/ossec.conf` | ? | ⚠️ TBD - check path |
| **Manager address config** | `<manager_address>` | ? | ⚠️ TBD - check tag |

**Action**: During testing:
  1. Deploy agent on separate instance
  2. Verify enrollment completes
  3. Verify agent appears in manager
  4. Check config format

---

## Breaking Changes (Potential)

Based on typical major-version upgrade patterns:

| Change | Likelihood | Impact | Workaround |
|--------|-----------|--------|-----------|
| API endpoint paths changed | Medium | Agent enrollment script breaks | Re-map endpoints after testing |
| Authentication flow changed | Medium | API clients need update | Check auth docs |
| Certificate format changed | Low | Cert regeneration needed | Use installer defaults |
| Config file format changed | Medium | Manual configs won't load | Regenerate configs |
| Log format changed | Low | Log parsing needs update | Update rules |

---

## Verification Checklist

Use during Phase 2 testing:

- [ ] Installation completes without errors
- [ ] All three services (manager, indexer, dashboard) are active
- [ ] Dashboard accessible at HTTPS
- [ ] Credentials retrievable from tar file
- [ ] Indexer accepts connections (check network.host)
- [ ] API responds to authentication request
- [ ] Agent can enroll to manager
- [ ] Agent appears in manager console
- [ ] Dashboard shows enrolled agent
- [ ] No breaking errors in logs

---

## Testing Timeline

**Phase 2 (this phase):**
  - Deploy v5_0_0 infrastructure
  - Collect installation output
  - Verify all services running
  - Document actual differences
  - Note any new gotchas

**Phase 3:**
  - Deploy test agents
  - Test EOL detection compatibility
  - Test TheHive integration (if supported)

**Phase 4:**
  - Test 4.14.6 → 5.0.0 upgrade path
  - Verify backward compatibility

---

## References

- Wazuh 5.0 Documentation: https://docs.wazuh.com/
- Wazuh Installation Guide: https://docs.wazuh.com/current/installation-guide/
- Wazuh API Reference: https://docs.wazuh.com/current/api/

---

**Last Updated**: Phase 2 (2026-07-29)  
**Status**: 📋 IN PROGRESS — Awaiting actual deployment testing
