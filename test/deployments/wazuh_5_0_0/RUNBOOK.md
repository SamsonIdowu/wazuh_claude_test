# Wazuh 5.0.0 Deployment Runbook

**Status:** 📋 IN PROGRESS — Under Phase 2 research

This runbook documents the procedure and known gotchas for deploying Wazuh 5.0.0 on AWS.

---

## Overview

Wazuh 5.0.0 introduces breaking changes from 4.14.6. This document captures what works and what fails.

> **IMPORTANT**: This is a stub. Fill in after Phase 2 research is complete.

---

## 1. Installation Procedure

**Research needed:**
- [ ] Does 5.0.0 use `/5.x/` URL format like 4.14.6 uses `/4.x/`?
- [ ] What is the exact quickstart installer URL?
- [ ] Are the install flags (`-a -i`) the same?
- [ ] What is the estimated installation time?

**Preliminary approach:**
```bash
WAZUH_BRANCH=5.0                    # RESEARCH: Is this the right branch format?
curl -sO "https://packages.wazuh.com/${WAZUH_BRANCH}/wazuh-install.sh"
bash ./wazuh-install.sh -a -i
```

---

## 2. Known Issues (To be documented)

### Indexer Configuration
**Research needed:**
- [ ] Does Indexer bind to localhost-only like in 4.14.6?
- [ ] Is the config location still `/etc/wazuh-indexer/opensearch.yml`?
- [ ] Do we need the same workaround?

### SSL Certificates
**Research needed:**
- [ ] Where are certificates stored?
- [ ] How are they generated?
- [ ] Any changes to certificate format?
- [ ] Regeneration procedure if needed?

### Credentials
**Research needed:**
- [ ] Are passwords still random (not `admin/admin`)?
- [ ] Is retrieval still via `tar -xOf /root/wazuh-install-files.tar`?
- [ ] Are there separate accounts (`admin`, `wazuh-wui`)?

---

## 3. API Changes

**Research needed:**
- [ ] What endpoints changed from 4.14.6?
- [ ] Are authentication endpoints compatible?
- [ ] What about the JWT flow?
- [ ] Any breaking changes in response formats?

---

## 4. Dashboard Changes

**Research needed:**
- [ ] Is the login URL still HTTPS on port 443?
- [ ] Are default credentials process the same?
- [ ] Any UI layout changes?
- [ ] Does it still connect to Indexer on port 9200?

---

## 5. Agent Enrollment

**Research needed:**
- [ ] Is the enrollment process different?
- [ ] Does agent use the same port (1514)?
- [ ] Any changes to agent config format?
- [ ] Backward compatibility with 4.14.6 agents?

---

## Verification (To be tested)

Once installed, verify with:

```bash
for s in wazuh-manager wazuh-indexer wazuh-dashboard; do
  systemctl is-active $s
done

curl -k -o /dev/null -w '%{http_code}\n' https://<SERVER_IP>

# Verify API (requires credentials)
curl -k -u 'wazuh-wui:<PASSWORD>' -X POST \
  https://<SERVER_IP>:55000/security/user/authenticate
```

---

## Timeline

- [ ] Estimated installation: ~30 minutes (verify)
- [ ] Estimated service readiness: ~5 minutes after install
- [ ] Full provisioning check: ~10 minutes

---

## Differences from 4.14.6

| Component | 4.14.6 | 5.0.0 | Notes |
|-----------|--------|-------|-------|
| Install URL | `/4.14/` | `/5.x/` ? | **RESEARCH** |
| Indexer binding | localhost-only | ? | **RESEARCH** |
| Certificates | `/root/wazuh-install-files.tar` | ? | **RESEARCH** |
| API endpoints | Known | ? | **RESEARCH** |
| Dashboard port | 443 | 443 ? | **RESEARCH** |
| Agent port | 1514 | 1514 ? | **RESEARCH** |

---

## Reference

- **Wazuh 5.0 Docs**: https://docs.wazuh.com/
- **Installation Guide**: [Link to be added]
- **API Reference**: [Link to be added]

---

**Last Updated**: Phase 1 (2026-07-29)  
**Phase Status**: 📋 IN PROGRESS — Awaiting Phase 2 research
