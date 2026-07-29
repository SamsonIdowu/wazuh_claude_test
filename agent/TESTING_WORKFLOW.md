# Agent Testing Workflow: How to Provide Documents

This guide explains how to provide documents/blog posts/requirements to agents for testing.

---

## Three Ways to Provide Test Documents

### Option 1: Direct URL (Recommended)

**For blog posts, documentation, or online resources:**

Tell the agent:
```
Test this blog post: https://example.com/eol-detection-guide
```

OR

```
Validate this documentation: https://docs.wazuh.com/5.0/installation-guide/
```

**Agent will**:
1. Fetch and read the URL
2. Analyze infrastructure requirements
3. Generate test-specific code in `test/terraform/`
4. Deploy and test
5. Document findings

**Best for**: Public blog posts, official docs, online resources

---

### Option 2: Local Document File

**For documents already in the repository:**

Put document in `test/requirements/`:
```
test/requirements/
├── custom-integration.md
├── custom-rules.xml
├── eol_detector.py
└── integration-spec.txt
```

Tell the agent:
```
Test the integration described in test/requirements/custom-integration.md
```

**Agent will**:
1. Read from `test/requirements/`
2. Analyze and understand requirements
3. Reference files when generating test code
4. Deploy and test
5. Document findings

**Best for**: Internal specifications, custom integrations, local files

---

### Option 3: Paste Content Directly

**For short documents or requirements:**

Tell the agent:
```
Test the following blog post procedure:

1. Install the EOL detection script to /var/ossec/integrations/
2. Add the following rule to ossec.conf:
   <integration>
     <name>eol_detector</name>
   </integration>
3. Restart the manager
4. Verify by checking /var/log/eol-detection.log
```

**Agent will**:
1. Parse the pasted requirements
2. Extract infrastructure needs
3. Generate test code
4. Deploy and test
5. Document findings

**Best for**: Short procedures, email content, chat messages

---

## Workflow Example: Testing a Blog Post

### Step 1: Provide Document to Agent

```
Test this blog post about Wazuh integration:
https://example.com/wazuh-custom-integration-guide

Focus on:
- Security group requirements
- Custom script deployment
- Integration configuration
- Verification procedures
```

### Step 2: Agent Analyzes

Agent reads the blog post and determines:
- What security groups are needed?
- What scripts need to be deployed?
- What configuration changes?
- What should be verified?

### Step 3: Agent Generates Test Code

Agent creates in `test/terraform/`:
```bash
cat > test/terraform/generated-integration-test.tf << 'EOF'
# Generated from: https://example.com/wazuh-custom-integration-guide
# Purpose: Test custom Wazuh integration deployment

resource "aws_security_group_rule" "custom_api_access" {
  # Allow external API calls for the integration
  ...
}

resource "local_file" "integration_script" {
  filename = "/tmp/custom-integration.py"
  content  = file("${path.module}/../requirements/custom-integration.py")
}

resource "local_file" "integration_config" {
  filename = "/tmp/ossec-integration.conf"
  content  = templatefile("${path.module}/../templates/integration.conf", {
    # Integration config variables
  })
}
EOF
```

### Step 4: Agent Deploys

```bash
cd terraform
terraform apply  # Deploys baseline + generated test code
```

### Step 5: Agent Tests

Agent SSH to server and:
1. Verifies infrastructure deployed correctly
2. Executes procedures from the blog post
3. Documents actual vs expected outcomes
4. Notes any discrepancies

### Step 6: Agent Documents Findings

Creates in `results/`:
```
test-verdict.md
- Overall result: PASS/FAIL/PARTIAL
- Procedures verified: [list]
- Issues found: [list]
- Recommendations: [list]

execution-log.txt
- Timeline of test execution
- Each step verified/unverified
```

### Step 7: Agent Cleans Up

```bash
terraform destroy
rm -rf test/terraform/
rm -rf results/
```

Result: Repository back to baseline, ready for next test.

---

## What Agent Needs From Document

Regardless of how you provide it, the document should include:

### Required
- **What to test**: Feature name, integration name, procedure name
- **How to test**: Step-by-step procedures
- **How to verify**: Commands to confirm it works
- **Expected outcome**: What should happen

### Helpful
- **Infrastructure needs**: Ports, security groups, external services
- **Configuration**: Config file contents or settings
- **Prerequisites**: Dependencies, versions, prior setup
- **Troubleshooting**: Known issues and how to fix them

---

## Document Examples

### Example 1: Blog Post URL

```
Test the Wazuh EOL detection blog post:
https://wazuh.com/blog/detecting-end-of-life-software

The blog describes a Python integration that:
- Runs daily
- Checks software versions against endoflife.date API
- Generates alerts for EOL software
- Requires external API access (port 443)

Focus on verifying:
1. Integration installation works
2. API connectivity succeeds
3. Alerts generate correctly
```

### Example 2: Local File

```
Test the integration in test/requirements/custom-rules.xml

The file defines:
- Custom detection rules for specific software
- Decoder configuration
- Alert thresholds

Verify:
1. Rules load without errors
2. Test data triggers correct rules
3. Alerts match expected format
```

### Example 3: Inline Procedure

```
Test this Wazuh 5.0 authentication integration:

1. SSH to server: ssh -i terraform/wazuh-test-key.pem ubuntu@<dns>

2. Deploy custom integration:
   sudo cp /tmp/auth-integration.py /var/ossec/integrations/
   sudo chown wazuh:wazuh /var/ossec/integrations/auth-integration.py

3. Update ossec.conf with:
   <integration>
     <name>auth-integration</name>
     <hook_url>https://auth.example.com/verify</hook_url>
   </integration>

4. Restart manager:
   sudo systemctl restart wazuh-manager

5. Verify with:
   curl -k https://localhost:55000/api/version
```

---

## Best Practices

### For Blog Posts
- **Provide the URL** — Agent can fetch and analyze
- **Highlight requirements** — What resources are needed?
- **Note any dependencies** — External services, credentials, etc.

### For Documentation
- **Link to official docs** — https://docs.wazuh.com/5.0/...
- **Specify the section** — "Installation on Ubuntu 22.04"
- **List procedures** — What exact steps to follow?

### For Custom Integrations
- **Put files in test/requirements/** — Scripts, configs, rules
- **Document the purpose** — What does this do?
- **List deployment steps** — How to put it in place?

### For Procedures
- **Be specific** — Exact commands, not descriptions
- **Include verification** — How to confirm it worked?
- **Note prerequisites** — What must be set up first?

---

## What Happens Next

Once you provide the document:

1. **Agent reads and analyzes** (5-10 min)
2. **Agent generates infrastructure** (5 min)
3. **Agent deploys** (45 min)
4. **Agent tests** (15-60 min depending on test)
5. **Agent documents** (10 min)
6. **Agent cleans up** (2 min)

**Total time**: 60-120 minutes depending on test complexity  
**Cost**: $0.21-0.84 depending on duration

---

## Common Document Types

| Type | How to Provide | Best Format |
|------|---------------|----|
| Blog post | URL | `https://example.com/blog-post` |
| Official docs | URL | `https://docs.wazuh.com/5.0/...` |
| Custom script | File in test/requirements/ | `.py`, `.sh`, `.js` |
| Config | File in test/requirements/ | `.xml`, `.conf`, `.json` |
| Procedure | Paste directly | Numbered steps with commands |
| Research paper | Local file | `.md` or `.pdf` (if readable) |

---

## Example Agent Prompts

### Testing a Blog Post
```
Test this Wazuh integration guide:
https://medium.com/wazuh-community/custom-integration

The post describes a Python webhook receiver that logs events.
Verify: installation, startup, event reception, log output.
```

### Testing Documentation
```
Validate the Wazuh 5.0.0 installation documentation:
https://docs.wazuh.com/5.0/installation-guide/

Follow the "All-in-one deployment" procedure exactly.
Verify each step completes and services start correctly.
```

### Testing Custom Integration
```
Test the custom rules in test/requirements/custom-rules.xml

The rules detect brute-force SSH attempts.
Deploy to the server and verify:
1. Rules load without error
2. Test data triggers correct alert
3. Alert format matches expected output
```

---

## Notes

- **Agent will ask for clarification** if the document is unclear
- **Agent will generate what's needed** — you don't specify infrastructure, just the test
- **Agent verifies with actual commands** (R1 rule — no assumptions)
- **Agent documents discrepancies** if actual != expected
- **Repository stays clean** — all test code deleted after cleanup

---

**Last Updated**: 2026-07-29  
**Status**: Ready for agent use
