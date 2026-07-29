# Documentation Testing Template

**Purpose**: Validate official Wazuh documentation against a live deployment. Use this template to systematically verify that documented procedures work, identify outdated information, and capture what the actual UI/API/CLI look like.

**When to use**: 
- When Wazuh releases new documentation (5.0, 5.1, etc.)
- When testing a new major version
- When verifying documented procedures match actual behavior
- To catch documentation errors before they reach users

---

## Configuration

### Source Documentation

```
DOCUMENT_TITLE:     Wazuh 5.0 Installation Guide
DOCUMENT_URL:       https://docs.wazuh.com/5.0/installation-guide/
WAZUH_VERSION:      5.0.0
TEST_DATE:          2026-07-29
TESTER:             [Your name]
```

### Test Infrastructure

```
DEPLOY_WITH:        terraform apply -var="test_scenario=documentation_test" \
                                    -var="wazuh_major_version=5"
SERVER_TYPE:        t3.xlarge, Ubuntu 22.04
TTL:                240 minutes
```

---

## Test Procedure

### Phase 1: Deploy Infrastructure

Deploy a fresh Wazuh instance for documentation testing:

```bash
cd terraform
terraform apply \
  -var="test_scenario=documentation_test" \
  -var="wazuh_major_version=5"

# Save outputs
terraform output > /tmp/deployment-outputs.txt

# Get server DNS
SERVER_DNS=$(terraform output -raw wazuh_server_public_dns)
SSH_KEY="wazuh-test-key.pem"
```

### Phase 2: Extract Actual Procedures from Documentation

For each major section in the documentation:

1. **Write the documented procedure**
   ```
   DOC PROCEDURE:
   [Copy exact steps from documentation]
   ```

2. **Predict what will happen**
   ```
   EXPECTED OUTCOME:
   [What should happen if the doc is correct]
   ```

3. **Note the verification method**
   ```
   HOW TO VERIFY:
   [Command or observation that proves it worked]
   ```

### Phase 3: Execute and Verify

For each procedure:

```bash
# SSH to server
ssh -i $SSH_KEY ubuntu@$SERVER_DNS

# Run documented steps (exactly as written)
# Example: sudo systemctl status wazuh-manager

# Capture output
# Example: MANAGER_STATUS=$(sudo systemctl is-active wazuh-manager)

# Compare to expected outcome
```

### Phase 4: Document Findings

For each tested procedure:

```markdown
## Procedure: [Name from docs]

**Source**: [Section in documentation]

### Documented Steps
[Exact copy from docs]

### Expected Outcome
[What should happen]

### Actual Outcome
[What actually happened]

### Verification
[Command used to verify]

### Status
- [✅ CORRECT] Documentation matches behavior
- [⚠️ OUTDATED] Documentation is incomplete/incorrect
- [❌ BROKEN] Documented procedure fails

### Notes
[Any surprises, differences, or clarifications needed]
```

---

## Example: Installation Verification

### Procedure: Quickstart Installation

**Source**: Wazuh 5.0 Installation Guide - All-in-One Deployment

### Documented Steps
```
1. Download the quickstart installer
   curl -sO https://packages.wazuh.com/5.0/wazuh-install.sh

2. Run with all-in-one flag
   bash ./wazuh-install.sh -a -i

3. Wait for completion (approximately 30 minutes)

4. Access Dashboard at https://<server-ip>
   Username: admin
   Password: see /root/wazuh-install-files/wazuh-passwords.txt
```

### Expected Outcome
- Script downloads without errors
- Installation completes in ~30 minutes
- Three services start automatically
- Dashboard accessible via HTTPS
- Admin password retrievable from tar file

### Actual Outcome
[To be filled in during Phase 3 testing]

### Verification Commands
```bash
# Verify download
curl -s -o /dev/null -w '%{http_code}' \
  https://packages.wazuh.com/5.0/wazuh-install.sh

# Check services after install
for s in wazuh-manager wazuh-indexer wazuh-dashboard; do
  sudo systemctl is-active $s
done

# Get admin password
sudo tar -xOf /root/wazuh-install-files.tar \
  wazuh-install-files/wazuh-passwords.txt | grep -i "^admin:"

# Test dashboard
curl -k -u 'admin:<PASSWORD>' \
  https://localhost/api/version
```

### Status
- [ ] CORRECT
- [ ] OUTDATED
- [ ] BROKEN

### Notes
[Document any differences from expectations]

---

## Scope: Procedures to Test

Pick the procedures most important for your use case:

### Essential (Test all)
- [ ] Installation (quickstart installer)
- [ ] Service status verification
- [ ] Dashboard access
- [ ] Credential retrieval
- [ ] API authentication

### Important (Test most)
- [ ] Agent enrollment
- [ ] Rule management
- [ ] Alert viewing
- [ ] Configuration changes

### Optional (Test if relevant)
- [ ] User management
- [ ] Integration configuration
- [ ] Report generation
- [ ] Backup procedures

---

## Output: Documentation Audit Report

Create a summary document:

```markdown
# Documentation Audit Report — Wazuh 5.0

**Test Date**: [Date]
**Tested Version**: 5.0.0
**Tester**: [Name]

## Summary
- Procedures Tested: N
- Correct: N (✅)
- Outdated: N (⚠️)
- Broken: N (❌)

## Findings

### Critical Issues (Broken Documentation)
[List any procedures that don't work as documented]

### Important Issues (Outdated Information)
[List any incomplete or misleading information]

### Minor Issues (Clarifications Needed)
[List any confusing or ambiguous procedures]

## Recommendations

[Suggest fixes to Wazuh documentation]

## Files Used

- Server: $SERVER_DNS
- Key: $SSH_KEY
- Logs: [Path to captured output]
```

---

## R1 & R2 Verification Rules

Applying the same rules from the EOL detection testing:

**R1: Never report success without a command confirming it**
- Don't trust status messages alone
- Verify with functional commands (curl, systemctl, etc.)
- Capture actual output for audit trail

**R2: Verify URL before piping to shell**
- Test HTTP 200 before executing
- Document version of files downloaded

---

## Success Criteria

- ✅ All essential procedures tested
- ✅ Each test has documented verification
- ✅ Findings captured with examples
- ✅ No silent assumptions (R1 rule applied)
- ✅ Audit report created
- ✅ Ready to share findings with Wazuh docs team

---

## Next Steps

1. Deploy infrastructure with `test_scenario=documentation_test`
2. Work through procedures section by section
3. Document actual vs expected outcomes
4. Create audit report with findings
5. Share recommendations with Wazuh community

---

**Template Version**: Phase 3  
**Last Updated**: 2026-07-29  
**Status**: Ready for Phase 3 testing deployment
