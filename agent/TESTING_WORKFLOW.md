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

Creates in `results/` both **PDF and HTML** reports:

#### PDF Report (`test-report.pdf`)
```
├── Executive Summary
│   ├── Overall result: PASS/FAIL/PARTIAL
│   ├── Procedures verified: [count]
│   ├── Issues found: [count critical, important, minor]
│   └── Writing quality score
│
├── Technical Review
│   ├── Each procedure tested
│   │   ├── Status (✅ / ⚠️ / ❌)
│   │   ├── Actual vs Expected outcome
│   │   ├── Commands executed
│   │   └── Verification results
│   └── Code/configuration validation
│
├── Writing Quality Review
│   ├── Spelling/Grammar issues
│   ├── Code formatting issues
│   ├── Consistency issues
│   ├── Clarity issues
│   └── Recommendations
│
├── Structure & Automation Review
│   ├── Heading hierarchy findings
│   ├── Manual procedures identified as automatable
│   ├── Scripts written as proof-of-concept
│   └── Recommendations
│
└── Appendix
    ├── Full command outputs
    ├── Timestamps
    └── Evidence (screenshots, configs)
```

#### HTML Report (`test-report.html`)
```html
<dashboard>
  <status-indicators>
    <!-- Visual pass/fail rates, charts -->
  </status-indicators>
  
  <collapsible-findings>
    <!-- Each finding with severity badge, evidence, recommendation -->
  </collapsible-findings>
  
  <code-review>
    <!-- Syntax highlighting, validation results -->
  </code-review>
  
  <writing-review>
    <!-- Issues with line numbers and examples -->
  </writing-review>

  <structure-review>
    <!-- Heading hierarchy findings, automation opportunities + scripts -->
  </structure-review>
</dashboard>
```

Also creates supporting files:
```
test-verdict.md (summary)
- Overall result: PASS/FAIL/PARTIAL
- Procedures verified: [list]
- Critical issues: [list]
- Important issues: [list]
- Recommendations: [list]

execution-log.txt (timeline)
- Timeline of test execution
- Each step verified/unverified
- Timestamps and durations
```

### Step 7: Agent Saves Results (Optional)

Before cleanup, optionally save the test reports:
```bash
# Save reports externally if needed
cp results/test-report.pdf ~/wazuh-tests/2026-07-29-integration-test.pdf
cp results/test-report.html ~/wazuh-tests/2026-07-29-integration-test.html
```

### Step 8: Agent Cleans Up

```bash
terraform destroy
# Verify against AWS directly, not just the exit code:
aws ec2 describe-instances --profile wazuh \
  --filters "Name=tag:Name,Values=wazuh-server,wazuh-agent" \
  --query "Reservations[].Instances[].State.Name"

rm -rf test/terraform/      # Delete test-specific code
rm -rf results/*            # Delete test outputs (keep the .gitkeep)
rm -rf test/requirements/*  # Delete reconstructed configs/policies
```

**Sweep for stragglers.** Those directories are where things are *supposed*
to live, but always check for test-specific scripts you created elsewhere
during the test (a one-off provisioning script written straight into a
scratch path, a script scp'd to the instance and also kept locally, etc.) and
remove those too — `git status --short` after the `rm -rf` above should show
nothing new at all. Habit, every time, not just when something looks
obviously left over.

Result: Repository back to baseline, ready for next test — nothing from this
test kept unless the user explicitly asks for it.

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

## Writing Quality Checks

When testing documentation or blog posts, agents should also verify **writing quality** alongside functional correctness:

### Grammar & Punctuation
- Spelling errors (typos, misspelled commands/filenames)
- Sentence structure (run-ons, fragments, dangling modifiers)
- Punctuation consistency (periods, commas, colons)
- Capitalization (titles, proper nouns, acronyms)

### Code Formatting & Style
- Code blocks properly marked (```language tags)
- Commands in monospace or code blocks
- File paths formatted consistently
- Variable/command names styled (e.g., `var_name`, `command`)
- Output vs instructions clearly distinguished

### Documentation Style
- Consistent heading hierarchy (# ## ### usage)
- Numbered lists (1. 2. 3.) vs bullet points (- •)
- Markdown formatting (links, bold, italics) used correctly
- Tables properly aligned with borders
- Code indentation and alignment

### Clarity & Consistency
- Consistent terminology (not switching between terms)
- Clear prerequisites listed
- Assumptions stated explicitly
- Warnings and notes clearly marked
- Section references accurate and working

### Document Issues Found
Agents should report writing issues separately from functional issues:

**Format for findings:**
```
### Writing Quality Issues

**Critical** (blocks understanding):
- [Description] at [location]

**Important** (confusing but workable):
- [Spelling]: "[word]" should be "[correction]"
- [Formatting]: [example of issue]
- [Consistency]: [what changed]

**Minor** (polish/style):
- [Line spacing], [capitalization], [emphasis]
```

## Document Structure & Automation Checks

Writing quality covers *wording*. Separately, agents should review the
document's *shape* — its heading hierarchy, and whether its technical steps
are needlessly manual.

### Heading Hierarchy
- Does each heading's level match its actual role, or is a true subsection
  sitting at the same level as its parent (or vice versa)?
- Watch for a run of subheadings that each contain nothing but a bullet list
  with no distinguishing prose — that's usually one reference list that got
  artificially split into fake sections. Recommend collapsing it into a
  single list with bold run-in labels instead.
- Check that numbered steps don't silently restart at "1." when a code block
  or table sits between them (a common markdown-export artifact, but also
  sometimes a real authoring issue worth flagging either way).

### Automation Opportunities
- For any procedure with 3+ manual steps that touch files or configuration —
  especially ones involving hand-pasting large blocks of code/config — ask:
  could this be one script instead? Manual multi-step file edits are exactly
  where transcription errors happen, both for the reader and for anyone
  extracting the doc programmatically (this tester included).
- Don't just note that automation is possible — **write the script** (or a
  working excerpt) and include it in the findings. A working script is much
  stronger evidence than a described opportunity.
- A script that replaces a "go check the dashboard" step should verify its
  own result with a command and print it, matching this repo's R1 rule
  (verify with a command, never trust status alone).

### Document Issues Found
Report these alongside writing issues, in their own bucket:
```
### Structural / Automation Findings

- Heading over-splitting: [which section — should merge into one list?]
- Heading under-nesting: [which subsection reads as a sibling but isn't?]
- Manual procedure automatable: [which steps — script attached]
```

## What Happens Next

Once you provide the document:

1. **Agent reads and analyzes** (5-10 min)
2. **Agent reviews writing quality** (5 min)
3. **Agent reviews document structure and automation opportunities** (5 min)
4. **Agent generates infrastructure** (5 min)
5. **Agent deploys** (45 min)
6. **Agent tests** (15-60 min depending on test)
7. **Agent documents findings** (15-20 min)
   - Generates PDF report with technical + writing + structure/automation review
   - Generates HTML report with interactive dashboard
   - Creates supporting markdown summary and execution log
8. **Agent cleans up** (2 min)

**Total time**: 85-150 minutes depending on test complexity  
**Cost**: $0.21-0.84 depending on duration  
**Outputs**: PDF + HTML reports in results/ (deleted after optional backup)

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

## Writing Standards for Documentation Testing

When validating documentation quality, agents should enforce these standards:

### Grammar & Language
- **Spelling**: No misspellings in commands, file paths, or prose
- **Tense**: Consistent tense (usually imperative for procedures: "Run", "Configure", "Verify")
- **Voice**: Active voice preferred in procedures ("Run the command" vs "The command should be run")
- **Subject consistency**: Use consistent terms (e.g., "manager" or "server" but not both for same component)

### Code Examples & Command Formatting
- **Code blocks**: Use triple backticks with language identifier (```bash, ```json, ```yaml)
- **Inline code**: Use backticks for file paths, commands, variables (e.g., `wazuh-manager`)
- **Command output**: Clearly distinguish from instructions using code blocks
- **Continuation lines**: Use backslash continuation (\\) with proper formatting
- **Variables**: Indicate replaceable parts with `<angle_brackets>` or `${VARIABLE}`
- **Prompts**: Distinguish shell prompts (# for root, $ for user)

### Structure & Formatting
- **Headings**: Use proper hierarchy (# > ## > ### > ####)
- **Lists**: 
  - Numbered (1. 2. 3.) for sequential steps
  - Bullets (- or •) for non-sequential items
  - Consistent indentation for nested items
- **Emphasis**: Bold for UI elements, italics for emphasis, code for technical terms
- **Links**: Format as [text](url) with working URLs
- **Tables**: Use | | | format with proper alignment

### Documentation Quality
- **Prerequisites**: List all required setup before procedures
- **Warnings**: Use clear markers like `**Warning:**` or `**Note:**`
- **Expected outcomes**: State what happens on success
- **Troubleshooting**: Document common errors and solutions
- **Prerequisites first**: List what must be installed/configured before steps

### Style Consistency Checklist
- [ ] Terminology consistent throughout (no "dashboard" vs "UI" switching)
- [ ] All file paths use forward slashes or proper OS separator
- [ ] All commands properly formatted in code blocks with language tag
- [ ] All external links work (return HTTP 200 or 302)
- [ ] All headings follow title case or sentence case consistently
- [ ] All numbered procedures start at 1, not 0
- [ ] All environment variables use ALL_CAPS convention
- [ ] All file/folder names use proper case (lowercase with hyphens vs underscores)
- [ ] No double spaces or trailing whitespace
- [ ] Consistent bullet point style (- or • but not mixed)
- [ ] All tables have proper column alignment
- [ ] All code examples are syntactically valid

### Issues to Flag
**Critical** (must fix before publication):
- Commands that fail due to typos
- Broken links
- Syntax errors in code examples
- Missing prerequisites
- Contradictory instructions

**Important** (confusing but workable):
- Inconsistent terminology
- Unclear expected outcomes
- Missing error descriptions
- Typos in command examples
- Improper formatting

**Minor** (polish):
- Spacing inconsistencies
- Capitalization inconsistencies
- Heading level issues
- List formatting inconsistencies
- Extra whitespace

## Notes

- **Agent will ask for clarification** if the document is unclear
- **Agent will generate what's needed** — you don't specify infrastructure, just the test
- **Agent verifies with actual commands** (R1 rule — no assumptions)
- **Agent verifies URLs return HTTP 200/302** (R2 rule — before piping to shell)
- **Agent checks writing quality** (R3 rule — documentation is usable only if it's readable)
- **Agent reviews structure and automates what it can** (R4 rule — heading hierarchy matches content, and manual multi-step procedures get a proof-of-concept script, not just a suggestion)
- **Agent documents discrepancies** if actual != expected
- **Repository stays clean** — all test code deleted after cleanup

---

**Last Updated**: 2026-07-29  
**Status**: Ready for agent use  
**Includes**: Writing quality standards (R3 rule)
