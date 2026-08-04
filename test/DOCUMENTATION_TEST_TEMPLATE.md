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
DEPLOY_WITH:        terraform apply -var="wazuh_version=5.0.0"
SERVER_TYPE:        t3.xlarge, Ubuntu 22.04
TTL:                240 minutes
```

---

## Test Procedure

### Phase 1: Deploy Infrastructure

Deploy a fresh Wazuh instance for documentation testing:

```bash
cd terraform
terraform apply -var="wazuh_version=5.0.0"

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

### Phase 4: Validate Writing Quality

Before executing procedures, review the documentation against
**`test/Language and formatting style guide for technical writing _ Wazuh.md`**
— the authoritative Wazuh style guide. Read it directly rather than relying
only on the checklist below, which highlights the most mechanical/checkable
rules from it.

**Grammar & Punctuation** (see the guide's A-Z "Language and grammar" reference)
- [ ] No spelling errors
- [ ] Consistent punctuation (periods at end of sentences); Oxford comma in lists of three or more
- [ ] Sentence-style capitalization for titles/headings (not Title Case, except marketing copy)
- [ ] Consistent contractions (don't vs do not) — never contract "Wazuh" itself
- [ ] No double spaces or extra whitespace
- [ ] No banned words: *could/should/would/may*, *etc./i.e./e.g.*, *please* (in instructions)
- [ ] Correct *can* / *might* / *may* usage — *can* for user actions, *might* for uncertain outcomes, never *may*
- [ ] No gender-specific pronouns (*he/she*) — *you*, *they*, or *the user*
- [ ] No possessive of product/company names ("the Wazuh agent," not "Wazuh's agent")
- [ ] No deprecated terminology, especially in rule/decoder descriptions: *OpenSCAP, OpenSearch, Kibana, ElasticSearch*
- [ ] Any custom Wazuh rule IDs fall in the 100000–120000 range

**Code Formatting & Style**
- [ ] Code blocks properly formatted (```language)
- [ ] Commands in monospace or code blocks
- [ ] File paths formatted consistently
- [ ] Variable names styled (e.g., `var_name`)
- [ ] Command output properly distinguished from instructions

**Documentation Style**
- [ ] Consistent heading levels (# ## ###)
- [ ] Numbered steps (1. 2. 3.) not lettered, and numbering doesn't restart
      mid-procedure (a code block or table between steps shouldn't reset the
      list back to "1.")
- [ ] Bullet points (- or •) used consistently
- [ ] Links properly formatted ([text](url)) — check the boundary is right,
      not just that brackets exist (`the[ agent]` with a stray space inside is
      a real, if minor, authoring slip, not a rendering artifact)
- [ ] Tables properly aligned
- [ ] Line length reasonable (< 100 chars preferred)

**Document Structure & Instructional Design**
- [ ] Heading hierarchy matches actual content hierarchy — no subheading that
      contains nothing but a bullet list with no distinguishing prose (a run
      of near-empty subheadings usually means a single reference list got
      split into fake sections; collapse it into one list with bold run-in
      labels instead)
- [ ] No section is nested a level too shallow or too deep relative to its
      actual role (e.g. a true subsection of another section using the same
      heading level as its parent, or vice versa)
- [ ] For any procedure with 3+ manual steps that touch files/config —
      especially ones that involve hand-pasting large blocks of code/config —
      ask: could this be one script instead? If yes, don't just say so —
      write the script (or a working excerpt of one) as part of the findings.
      This is usually the single highest-leverage recommendation in a
      documentation review, since manual multi-step file edits are exactly
      where transcription errors happen (both by the reader, and by anyone
      extracting the doc programmatically, e.g. this tester)
- [ ] A "does it work" script (if written) should verify its own result with
      a command and print it — not just tell the reader to go check a
      dashboard/UI. Matches this repo's R1 rule (verify with a command, never
      trust status alone)

**Clarity & Consistency**
- [ ] Consistent terminology (not switching between "server" and "manager")
- [ ] Consistent voice (active vs passive)
- [ ] Section references clear and accurate
- [ ] Prerequisites clearly listed
- [ ] Assumptions stated explicitly
- [ ] Warnings/notes clearly marked

**Issues Found**
Document any writing issues:
```markdown
### Writing Quality Issues

**Critical** (Block understanding):
- [ ] Unclear step (list which step)
- [ ] Missing prerequisite
- [ ] Inconsistent terminology

**Important** (Confusing but workable):
- [ ] Spelling error: "[word]" should be "[correction]"
- [ ] Punctuation issue: [location]
- [ ] Formatting issue: [example]

**Minor** (Polish/style):
- [ ] Inconsistent spacing
- [ ] Variable naming style
- [ ] Heading consistency

**Structural / Automation** (document design, not correctness):
- [ ] Heading over-splitting: [which section — should merge into one list?]
- [ ] Heading under-nesting: [which subsection reads as a sibling but isn't?]
- [ ] Manual multi-step procedure that could be one script: [which steps —
      attach the script, don't just note the idea]
```

### Phase 5: Document Findings

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

### Writing Quality
[Spelling, grammar, formatting issues found]

### Structure & Automation
[Heading hierarchy issues; whether any manual multi-step procedure here could
become a script — if so, attach the script]

### Status
- [✅ CORRECT] Documentation matches behavior, no writing issues
- [✅ CORRECT - MINOR ISSUES] Works as documented, has minor writing issues
- [⚠️ OUTDATED] Documentation is incomplete/incorrect
- [⚠️ OUTDATED - WRITING ISSUES] Outdated AND has writing problems
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

## Phase 6: Generate Test Results

After completing all tests, generate comprehensive results in **PDF** and **HTML** formats.

### PDF Report Contents
```
test-report.pdf
├── Executive Summary
│   ├── Total procedures tested: [N]
│   ├── Procedures passed: [N]
│   ├── Procedures failed: [N]
│   ├── Writing quality issues: [N]
│   └── Structural/automation recommendations: [N]
│
├── Technical Review
│   ├── Procedure: [Name]
│   │   ├── Status (✅ PASS / ⚠️ PARTIAL / ❌ FAIL)
│   │   ├── Actual vs Expected outcome
│   │   ├── Verification commands executed
│   │   ├── Code/configuration validation
│   │   └── Technical issues found
│   └── [Repeat for each procedure]
│
├── Writing Quality Review
│   ├── Overall writing quality score
│   ├── Spelling/Grammar issues with examples
│   ├── Code formatting issues
│   ├── Consistency issues
│   ├── Clarity issues
│   └── Recommendations for improvement
│
├── Structure & Automation Review
│   ├── Heading hierarchy findings (over-split / under-nested sections)
│   ├── Manual procedures identified as automatable
│   ├── Scripts written as proof-of-concept for each one
│   └── Recommendations for improvement
│
└── Appendix
    ├── Full command outputs
    ├── Screenshots (if applicable)
    └── Timestamp of test execution
```

### HTML Report Contents
```
test-report.html
├── Interactive Executive Summary
│   └── Charts/tables showing pass/fail rates and issue types
│
├── Technical Details (collapsible sections)
│   ├── Procedure [1]
│   │   ├── Status badge
│   │   ├── Before/after comparison
│   │   ├── Code block with syntax highlighting
│   │   └── Evidence (command output, screenshots)
│   └── [Repeat for each procedure]
│
├── Writing Quality Review
│   ├── Severity-based issue list
│   │   ├── Critical issues (with links to examples)
│   │   ├── Important issues (with line numbers)
│   │   └── Minor issues (style/polish)
│   └── Recommendations with specific examples
│
├── Structure & Automation Review
│   ├── Heading hierarchy findings (with the offending outline shown)
│   ├── Manual-steps-to-script findings (before/after, script attached)
│   └── Recommendations with specific examples
│
└── Navigation Menu
    └── Jump to section
```

### Technical Review Elements (in both formats)
- **Code Validation**: Is the code syntactically correct? Does it match the target version?
- **Commands Verified**: Which commands were executed? Did they return expected output?
- **Configuration Checked**: Are config examples valid? Do they match deployed software?
- **Version Compatibility**: Does procedure work for stated Wazuh version?
- **Dependencies**: Are prerequisites met? Are external services working?
- **Edge Cases**: What happens if user deviates from documented steps?

### Writing Review Elements (in both formats)
- **Clarity**: Are steps unambiguous? Are terms consistent?
- **Completeness**: Are all prerequisites listed? Are expected outcomes clear?
- **Formatting**: Are code blocks properly marked? Are commands in monospace?
- **Grammar**: Spelling, punctuation, sentence structure
- **Accessibility**: Can a new user follow these steps without prior knowledge?

### Structure & Automation Review Elements (in both formats)
- **Heading hierarchy**: Does each heading's level match its actual role? Any
  run of subheadings with nothing but a bullet list under them (should be one
  merged list, not N fake sections)?
- **Step count**: Does a procedure have more manual steps than the task
  actually requires human judgement for?
- **Automatability**: For any multi-step manual file/config edit, is there a
  reason a script couldn't do it? If not, write one and include it in the
  findings — a described opportunity is weaker evidence than a working script.
- **Self-verification**: Does the procedure (or the script replacing it) end
  by confirming success with a command, rather than pointing the reader at a
  UI to eyeball?

### Example PDF Section: Technical Review
```
## Procedure: Agent Installation

Status: ✅ PASS

### Steps Executed
1. ✅ Downloaded wazuh-agent package (verified HTTP 200)
2. ✅ Installed on Ubuntu 24.04 (installation completed in 2m 34s)
3. ✅ Configured enrollment credentials (auth verified)
4. ✅ Started service (systemctl is-active returns 'active')
5. ✅ Verified communication with server (agent appears in manager)

### Code Review
- Systemd service file valid syntax
- Configuration XML matches schema
- Firewall rules properly applied

### Issues Found
- None (PASS)

### Actual Output
[Full command output and timestamps]
```

### Example HTML Section: Writing Quality
```html
<section class="writing-review">
  <h2>Writing Quality Assessment</h2>
  <div class="issue critical">
    <h3>🔴 Critical: Ambiguous step</h3>
    <p>Step 3 says "configure the agent" but doesn't specify which configuration file or what values to set.</p>
    <code>Location: Section 2, Step 3</code>
    <p><strong>Recommendation:</strong> "Edit /var/ossec/etc/ossec.conf and set the following parameters: ...</p>
  </div>
  
  <div class="issue important">
    <h3>🟡 Important: Inconsistent terminology</h3>
    <p>Document switches between "agent" and "client" referring to the same component.</p>
    <code>Lines 24, 45, 67, 89</code>
    <p><strong>Recommendation:</strong> Use "agent" throughout.</p>
  </div>
  
  <div class="issue minor">
    <h3>🟢 Minor: Formatting inconsistency</h3>
    <p>Some code blocks use bash highlighting, others have no language specified.</p>
    <p><strong>Recommendation:</strong> Add ````bash` to all shell scripts.</p>
  </div>
</section>
```

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
- ✅ Heading hierarchy reviewed — no near-empty subheadings, no wrong nesting
- ✅ Every manual multi-step procedure evaluated for automation, with a script
     written for at least the most manual one found
- ✅ Audit report created
- ✅ Ready to share findings with Wazuh docs team

---

## Next Steps

1. Deploy infrastructure with `terraform apply -var="wazuh_version=<target version>"`
2. Work through procedures section by section
3. Document actual vs expected outcomes
4. Create audit report with findings
5. Share recommendations with Wazuh community

---

**Template Version**: Phase 4 — added Document Structure & Instructional Design review
**Last Updated**: 2026-07-29  
**Status**: Ready for Phase 3 testing deployment
