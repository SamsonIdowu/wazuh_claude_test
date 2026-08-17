# Wazuh 5.0.0 Deployment Runbook

**Status:** Live-tested 2026-08-17 against a real 5.0.0-beta4 deployment (see
`test/Results`/memory for the full FIM documentation test). Sections below
marked ✅ CONFIRMED are from that live test, not research/guesswork.

This runbook documents the procedure and expected differences for deploying Wazuh 5.0.0 on AWS.

> **IMPORTANT**: There is no separate `terraform/versions/` module for 5.0.0 —
> the baseline `terraform/` deploys any version via the `wazuh_version`
> variable. Deploy with `terraform apply -var="wazuh_version=5.0.0"` to test.
> **But read "Preferred Artifact Source" and "1. Installation Procedure"
> below first** — the baseline's `wazuh-server-init.sh`/`wazuh-agent-init.sh`
> hardcode `packages.wazuh.com` and 4.x-style flags, which do **not** work
> for 5.0.0/5.0-beta. Write a test-specific override script instead (see
> `terraform-override-tf-mechanism` in the project memory).

---

## Preferred Artifact Source

**Always use [`artifact_urls_5.0.0-latest.yaml`](artifact_urls_5.0.0-latest.yaml)
in this directory as the starting point for any 5.0 package/installer URL.**
Do not guess a version string (`5.0.0`, `5.0.0-beta4`, etc.) and hand-build a
`packages.wazuh.com` or `packages-staging.xdrsiem.wazuh.info` URL from it —
confirmed live on 2026-08-17 that a guessed/hardcoded version string
(`wazuh-agent=5.0.0-beta4`) fails outright even though the *installer script*
at a beta4-named path works fine; the actual installable package version in
the same repo was `5.0.0-1`, matching neither guess. The
`artifact_urls_5.0.0-latest.yaml` file uses the `-latest` tag (not a frozen
beta number) under a dated `nightly-backup/<date>/` path, which is the
convention that actually stays resolvable. If the dates in that file look
stale by the time you're testing, ask whoever supplied it for a refreshed
copy rather than falling back to guessed URLs — don't reverse-engineer a new
URL by pattern-matching the old one, since the pre-release distribution
paths/flags have already changed at least once (see "1. Installation
Procedure" below).

---

## Overview

Wazuh 5.0.0/5.0-beta does **not** use the same installation approach as
4.14.6. ⚠️ Confirmed live: it is **not** `packages.wazuh.com/5.0/wazuh-install.sh -a -i`
(see below) — it's a different distribution entirely, with its own installer
and (per "Preferred Artifact Source" above) its own package URLs that must
be looked up, not guessed from the 4.x pattern.

**Confirmed during live testing (2026-08-17):**
- Manager path moved: `/var/wazuh-manager/` (not `/var/ossec/`); binaries
  renamed `wazuh-manager-*`. Agent paths are unchanged (`/var/ossec/`).
- `agent_control` no longer exists — use the REST API (`GET /agents` on
  :55000) to check enrollment.
- Default dashboard/indexer credentials are the literal `admin`/`admin`
  (not random); API account is `wazuh-wui`/`wazuh-wui`. No
  `wazuh-passwords.txt` is generated.
- Agent enrollment needs `WAZUH_REGISTRATION_PASSWORD` at install time
  (the manager's `authd.pass`) — now documented on the agent-install pages,
  and works cleanly with no manual key-copy step when supplied.

---

## 1. Installation Procedure

✅ **CONFIRMED live 2026-08-17** (single-node, via the assisted all-in-one installer):

```bash
wget https://packages-staging.xdrsiem.wazuh.info/pre-release/5.x/installation-assistant/wazuh-install-5.0.0-beta4.sh
sudo bash ./wazuh-install-5.0.0-beta4.sh -a -id -d pre-release
```

- `-a` = all-in-one (manager+indexer+dashboard on one node); `-id` = auto
  install missing OS dependencies; `-d pre-release` selects the staging
  distribution channel. Works on Ubuntu 22.04 in ~9-15 minutes despite the
  installer's own OS-support check listing only 24.04/26.04.
- **This installer script path is itself version-pinned to `beta4`** and may
  already be superseded — check `artifact_urls_5.0.0-latest.yaml`'s
  `wazuh_installation_assistant` entry for the current URL before assuming
  the command above still resolves.
- The **package version actually installed** (`apt list --installed`,
  `dpkg -l | grep wazuh`) may not match the string in the installer's own
  filename — confirmed installing as `5.0.0-1` under a `wazuh-install-*beta4*.sh`
  script. Don't assume the two must match; verify with a command (R1).
- **IMPORTANT**: Always verify a URL returns HTTP 200 before piping to bash
  (R2) — this holds doubly for pre-release/staging URLs, which move more
  often than `packages.wazuh.com`.

---

## 2. Known Issues & Differences

### Indexer Configuration
**Status**: ⚠️ NEEDS VERIFICATION

Expected (based on 4.14.6 pattern):
- Config file: `/etc/wazuh-indexer/opensearch.yml`
- Likely localhost-only binding (same issue as 4.14.6)
- Workaround: `network.host: "0.0.0.0"` (pre-applied in init script)

**Action during testing**: Verify `network.host` setting and whether restart is needed.

### Credentials & Access
**Status**: ✅ CONFIRMED live 2026-08-17 — differs from 4.14.6

- Passwords: literal `admin`/`admin` (dashboard + indexer), `wazuh-wui`/`wazuh-wui` (API) —
  **not** random, unlike 4.14.6. No `wazuh-passwords.txt` is generated at all;
  `wazuh-install-files.tar` only contains certs + `config.yml`.
- Accounts: `admin` (dashboard), `wazuh-wui` (API)
- Dashboard: HTTPS on port 443
- API: Port 55000

### SSL Certificates
**Status**: ✅ EXPECTED SAME

- Generated by quickstart installer
- No manual certificate management required
- Same paths as 4.14.6

---

## 3. API & Authentication

**Status**: ⚠️ NEEDS VERIFICATION

Expected (based on major-version patterns):
- Base endpoint: `/api` (likely same)
- Authentication: JWT via POST `/security/user/authenticate`
- Account: `wazuh-wui` with random password
- Port: 55000

**Known risk**: API endpoint paths may have changed in 5.0. Test with:
```bash
curl -k -u 'wazuh-wui:<PASSWORD>' -X POST \
  https://<SERVER_IP>:55000/security/user/authenticate
```

**Action during testing**: Verify response format matches 4.14.6 expectations.

---

## 4. Dashboard & UI

**Status**: ✅ EXPECTED SAME

- URL: `https://<SERVER_IP>`
- Port: 443 (HTTPS)
- Credentials: `admin` + random password
- Connection: To Indexer on port 9200

---

## 5. Agent Enrollment

**Status**: ⚠️ NEEDS VERIFICATION

Expected (based on service continuity):
- Agent port: 1514 (TCP/UDP)
- Manager address config: `<manager_address>` tag
- Config file: `/var/ossec/etc/ossec.conf`
- Pre-auth enrollment still supported

**Action during testing**:
1. The baseline deploys server + agent at the *same* `wazuh_version` — there's
   no per-instance version variable. To test a 4.x agent against a 5.0 server,
   deploy the baseline at 5.0.0, then manually reinstall the agent package at
   4.14.6 over SSH (mirroring `terraform/wazuh-agent-init.sh`'s install steps
   at the older version) rather than expecting a Terraform variable to do it.
2. Verify agent enrolls to 5.0 server
3. Check for compatibility issues

---

## Verification Checklist

After deployment, run these checks:

### 1. Service Status (R1: Verify commands)
```bash
# SSH to server
ssh -i wazuh-test-key.pem ubuntu@<server_dns>

# Check all services active
for s in wazuh-manager wazuh-indexer wazuh-dashboard; do
  sudo systemctl is-active $s
done
# Expected: active (×3)
```

### 2. Dashboard Access (R1: Verify with functional endpoint)
```bash
# Get credentials
PASSWORDS=$(sudo tar -xOf /root/wazuh-install-files.tar \
  wazuh-install-files/wazuh-passwords.txt)

# Note admin and wazuh-wui passwords
echo "$PASSWORDS"

# Try dashboard (browser or curl)
curl -k -o /dev/null -w '%{http_code}\n' https://<server_dns>
# Expected: 302 (redirect to login)
```

### 3. API Authentication (R1: Verify JWT flow)
```bash
# Get wazuh-wui password from above
curl -k -u 'wazuh-wui:<PASSWORD>' -X POST \
  https://<SERVER_IP>:55000/security/user/authenticate
# Expected: JSON with JWT token
```

### 4. Indexer Configuration (R1: Verify with command)
```bash
# Check network.host setting
sudo grep "network.host" /etc/wazuh-indexer/opensearch.yml
# Expected: network.host: "0.0.0.0" (or "127.0.0.1" if issue persists)

# If localhost-only, apply workaround
sudo sed -i 's|^network.host: .*|network.host: "0.0.0.0"|' \
  /etc/wazuh-indexer/opensearch.yml
sudo systemctl restart wazuh-indexer
sleep 5
sudo systemctl is-active wazuh-indexer
# Expected: active
```

### 5. Complete Verification
```bash
# Log everything for documentation
echo "=== Services ===" > /tmp/wazuh-5.0-verify.txt
for s in wazuh-manager wazuh-indexer wazuh-dashboard; do
  sudo systemctl is-active $s >> /tmp/wazuh-5.0-verify.txt
done

echo "" >> /tmp/wazuh-5.0-verify.txt
echo "=== Dashboard ===" >> /tmp/wazuh-5.0-verify.txt
curl -k -o /dev/null -w 'HTTP %{http_code}\n' https://localhost >> /tmp/wazuh-5.0-verify.txt 2>&1

echo "" >> /tmp/wazuh-5.0-verify.txt
echo "=== Indexer Network ===" >> /tmp/wazuh-5.0-verify.txt
sudo netstat -tlnp | grep 9200 >> /tmp/wazuh-5.0-verify.txt 2>&1 || sudo ss -tlnp | grep 9200 >> /tmp/wazuh-5.0-verify.txt

# Copy to local machine
cat /tmp/wazuh-5.0-verify.txt
```

---

## How to Deploy 5.0.0

### Prerequisites
- AWS credentials configured
- Terraform in terraform/ directory
- wazuh-test-key.pem ready (will be generated)

### Deployment
```bash
cd terraform

# Option 1: Use a variable flag
terraform apply -var="wazuh_version=5.0.0"

# Option 2: Update terraform.tfvars
# Add: wazuh_version = "5.0.0"
terraform apply
```

### What Happens
1. **Not** the baseline `terraform apply` alone — the baseline init scripts
   target 4.x's `packages.wazuh.com` and will not deploy 5.0/5.0-beta
   correctly. Write a test-specific `_override.tf` + init script that
   downloads from the URLs in `artifact_urls_5.0.0-latest.yaml` (see
   "Preferred Artifact Source" above and `terraform-override-tf-mechanism`
   in the project memory).
2. Script verifies each URL returns HTTP 200 before piping to bash (R2)
3. Installation runs (~9-15 minutes for all-in-one, confirmed live)
4. TTL enforcement activated (auto-terminates in configured time)
5. Services start automatically

### Timeline
- Infrastructure provisioning: 2-3 minutes
- Installation script: 30 minutes
- Service readiness: 5 minutes after install
- Full verification: 10 minutes
- **Total**: ~45 minutes

---

## Comparison to 4.14.6

See [COMPARISON.md](COMPARISON.md) for detailed side-by-side comparison.

**Quick summary:**
- Installation procedure: ✅ Same
- Services: ✅ Same
- Credentials: ✅ Same
- Indexer binding: ⚠️ Likely same issue (localhost-only)
- API endpoints: ⚠️ Needs verification
- Agent enrollment: ⚠️ Needs verification

---

## Reference

- **Preferred artifact URLs (check first)**: [`artifact_urls_5.0.0-latest.yaml`](artifact_urls_5.0.0-latest.yaml)
- **Wazuh 5.0-beta Docs**: https://documentation.wazuh.com/5.0-beta/
- **Installation Guide**: https://documentation.wazuh.com/5.0-beta/installation-guide/
- **API Reference**: https://documentation.wazuh.com/5.0-beta/user-manual/api/reference.html

---

**Last Updated**: 2026-08-17 (live FIM documentation test)
**Phase Status**: ✅ Sections above marked CONFIRMED are live-verified; sections still marked ⚠️ NEEDS VERIFICATION were out of scope for that test and remain research-only
