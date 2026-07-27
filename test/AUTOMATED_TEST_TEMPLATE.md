# Automated Test Execution Template

## Purpose
This file serves as a self-executing test automation guide. When you say "execute test" to Claude, it will:
1. Read this file
2. Extract the Google Drive document link
3. Read the document to understand test requirements
4. Create comprehensive test implementation steps
5. Deploy infrastructure (if needed)
6. Execute tests end-to-end
7. Generate test results and verdict

---

## 🧹 Clean Up Previous Test Run

If you're running a new test and want to clean up from a previous test run, use this prompt:

```
cleanup test
```

This will automatically:
- Destroy all AWS infrastructure (terraform destroy)
- Remove previous test results from Results/
- Reset terraform/terraform.tfvars (removing test-specific variables)
- Keep test templates and documentation intact
- Ready the repository for a fresh test

**Or manually clean up:**
```bash
# Destroy infrastructure
cd terraform
terraform destroy

# Remove previous test results
rm -f Results/test-*.md Results/execution-log.txt

# Reset terraform config (use example)
rm terraform/terraform.tfvars
cp terraform.tfvars.example terraform/terraform.tfvars
```

---

## Configuration

### Google Drive Document Link
**PASTE YOUR GOOGLE DRIVE LINK HERE:**
```
https://docs.google.com/document/d/1C66pKpeAqM4uoWy4cr0BJJv5GkeLBNbh6UR8uTdHS10/edit
```

**Instructions to update:**
1. Replace the URL above with your Google Drive document link
2. Ensure the document is readable (share with viewer access if needed)
3. Save this file
4. Tell Claude: "execute test"

---

## Automated Test Procedure (Do NOT Modify)

### When You Say "Execute Test", Claude Will:

#### Phase 1: Document Analysis
```
□ Read this file to extract Google Drive document link
□ Access the Google Drive document
□ Identify infrastructure requirements
□ Identify test implementation steps
□ Document expected outcomes
```

#### Phase 2: Test Planning & Infrastructure Analysis
```
□ Identify infrastructure requirements from document:
  - Instance types and sizes needed
  - OS versions required
  - Component versions (Wazuh, etc.)
  - Storage requirements
  - Network/security configurations
  - Any special parameters or settings
□ Generate/modify terraform scripts to match requirements:
  - Create terraform/terraform.tfvars with document-derived values
  - Update variables.tf if new parameters needed
  - Ensure all requirements are captured
□ Create detailed test implementation steps file in Results/ folder
□ Map blog post steps to test procedures
□ Plan test execution timeline
□ Verify infrastructure configuration matches document requirements
```

#### Phase 3: Infrastructure Setup
```
□ Verify terraform files are ready
□ Run setup.ps1 to auto-detect your IP
□ Run terraform init (if not done)
□ Run terraform plan
□ Run terraform apply
□ Wait for services to initialize (5-10 minutes)
```

#### Phase 4: Test Execution
```
□ SSH to Wazuh server
□ Deploy any required test scripts/configurations
□ Execute test steps sequentially
□ Capture output and results
□ Verify each step completion
```

#### Phase 5: Results & Verdict
```
□ Document test results
□ Create test-verdict.md file (Pass/Fail/Partial)
□ Create test-details.md with findings
□ Generate summary report
□ Save all outputs to Results/ folder
```

#### Phase 6: Cleanup
```
□ Option A: Auto-cleanup (wait 60 min or run terraform destroy)
□ Option B: Extend if more testing needed
□ Option C: Keep running for manual verification
```

---

## Expected Output Files

After "execute test" completes, you'll have:

```
Results/
├── test-implementation-steps.md    (Blog post steps → test procedures)
├── test-verdict.md                 (PASS/FAIL/PARTIAL summary)
├── test-details.md                 (Detailed findings and logs)
└── execution-log.txt               (Full execution timeline)
```

---

## How to Use This File

### First Time Setup:
1. Edit the "Google Drive Document Link" section above
2. Paste your document URL
3. Save this file

### To Execute Tests:
1. Simply message Claude: **"execute test"**
2. Claude will automatically read this file and run the entire test procedure
3. Wait for completion (typically 20-40 minutes)
4. Check Results/ folder for results

### To Modify Test Parameters:
Edit the sections below and Claude will adapt the procedure:

---

## Optional: Custom Test Parameters

### Deployment Configuration
```
# Edit if you want different resource settings:
aws_region = "us-east-1"
wazuh_version = "4.14.6"
resource_ttl_minutes = 60          # 1 hour default
enable_auto_termination = true     # Auto-cleanup enabled
```

### Test Scope (Optional)
```
# Mark which tests to run:
☐ Infrastructure deployment
☐ Service verification
☐ Blog post implementation steps
☐ EOL detection functionality
☐ Dashboard accessibility
☐ Alert generation and verification
☐ Full end-to-end workflow
```

### Test Timeout (Optional)
```
# Maximum time to wait for infrastructure:
timeout_minutes = 20               # Time to wait for services
```

---

## Claude Self-Execution Instructions

**These instructions are for Claude to follow when you say "execute test":**

```markdown
WHEN USER SAYS "execute test":

1. READ THIS FILE (AUTOMATED_TEST_TEMPLATE.md)
2. EXTRACT the Google Drive document link from Configuration section
3. READ the Google Drive document using mcp__claude_ai_Google_Drive__read_file_content
4. IDENTIFY:
   - Infrastructure requirements (instance types, OS, versions, storage, etc.)
   - Test implementation steps from blog post
   - Expected outcomes and acceptance criteria
5. GENERATE/MODIFY infrastructure scripts:
   - Create/update terraform/terraform.tfvars with:
     * Instance types and sizes from document
     * OS versions from document
     * Component versions from document
     * Storage requirements
     * Any other parameters mentioned
   - Update variables.tf if document requires new parameters
   - Ensure terraform can use document-derived values
6. CREATE test-implementation-steps.md in Results/ folder:
   - Document the infrastructure being used
   - Map each blog post step to actual test procedure
   - Reference the terraform configuration used
7. DEPLOY infrastructure:
   - Verify terraform files exist
   - Run setup.ps1 for IP detection
   - Run: terraform init && terraform plan && terraform apply
   - Wait 5-10 minutes for services
8. EXECUTE each test step (from test-implementation-steps.md):
   - SSH to instances
   - Configure Wazuh if needed
   - Run tests per procedures
   - Capture results
9. CREATE test-verdict.md (PASS/FAIL/PARTIAL)
10. CREATE test-details.md (findings and logs)
11. SAVE all results to Results/ folder
12. REPORT back with summary
```

---

## FAQ

### Q: What if the Google Drive document is private?
**A:** Make sure it's shared with viewer access. You may need to update sharing settings.

### Q: Can I cancel the test execution?
**A:** Yes, at any phase you can ask Claude to stop. Resources will stay running (use terraform destroy to cleanup).

### Q: What if infrastructure deployment fails?
**A:** Claude will report the error and stop. You can fix the issue and restart.

### Q: How do I extend the TTL if tests are running long?
**A:** Edit ../terraform/terraform.tfvars and change resource_ttl_minutes, then run terraform apply.

### Q: Can I run multiple tests?
**A:** Update the Google Drive document link and run "execute test" again.

---

## Command Reference

| Need | Command |
|------|---------|
| Start automated test | "execute test" |
| Stop test execution | "stop test" or Ctrl+C |
| Check test progress | "show test status" |
| View test results | "show test results" |
| Extend infrastructure TTL | Edit terraform.tfvars → terraform apply |
| Cleanup resources | "terraform destroy" |

---

## Version
- **Created:** 2026-07-27
- **Last Updated:** 2026-07-27
- **Status:** Ready for use
- **Compatibility:** Claude Code with Google Drive integration

---

## Next Steps

1. **Update the Google Drive Document Link** (see Configuration section above)
2. **Save this file**
3. **Tell Claude: "execute test"**
4. **Check test/ folder for results**

That's it! Claude will handle the rest automatically.

