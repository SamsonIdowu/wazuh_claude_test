# Cleanup Test Files and Infrastructure
# This script cleans up after a test run

Write-Host "╔════════════════════════════════════════════════════════════╗"
Write-Host "║          WAZUH TEST INFRASTRUCTURE CLEANUP                 ║"
Write-Host "╚════════════════════════════════════════════════════════════╝"
Write-Host ""

$confirm = Read-Host "This will destroy infrastructure and remove test results. Continue? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Cleanup cancelled."
    exit 0
}

Write-Host ""
Write-Host "Step 1: Destroying Terraform infrastructure..."
Write-Host ""

Set-Location terraform
if (Test-Path "terraform.tfvars") {
    Write-Host "Running: terraform destroy"
    & terraform destroy -auto-approve
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Infrastructure destroyed"
    } else {
        Write-Host "⚠️  Terraform destroy completed with warnings"
    }
} else {
    Write-Host "⚠️  No terraform.tfvars found - skipping destroy"
}

Set-Location ..

Write-Host ""
Write-Host "Step 1b: Verifying teardown against AWS (don't trust the exit code alone)..."
Write-Host ""

$region = "us-east-1"
$profile = "wazuh"
$tfvarsPath = "terraform/terraform.tfvars"
if (Test-Path $tfvarsPath) {
    $match = Select-String -Path $tfvarsPath -Pattern 'aws_region\s*=\s*"([^"]+)"' -ErrorAction SilentlyContinue
    if ($match) { $region = $match.Matches[0].Groups[1].Value }
    $matchProfile = Select-String -Path $tfvarsPath -Pattern 'aws_profile\s*=\s*"([^"]+)"' -ErrorAction SilentlyContinue
    if ($matchProfile) { $profile = $matchProfile.Matches[0].Groups[1].Value }
}

$awsCmd = Get-Command aws -ErrorAction SilentlyContinue
if ($awsCmd) {
    $remaining = & aws ec2 describe-instances --region $region --profile $profile `
        --filters "Name=tag:Name,Values=wazuh-server,wazuh-agent,thehive-server" `
                  "Name=instance-state-name,Values=pending,running,stopping,stopped" `
        --query 'Reservations[].Instances[].InstanceId' --output text 2>$null
    if ($remaining) {
        Write-Host "⚠️  Instances still present in AWS: $remaining"
        Write-Host "    Investigate before assuming this cleanup is complete."
    } else {
        Write-Host "✅ Confirmed: no wazuh-server/wazuh-agent/thehive-server instances remain in $region"
    }
} else {
    Write-Host "⚠️  aws CLI not found - could not verify against AWS. Check the console manually."
}

Write-Host ""
Write-Host "Step 2: Removing test result files..."
Write-Host ""

$resultsFiles = @(
    "results/test-implementation-steps.md",
    "results/test-verdict.md",
    "results/execution-log.txt",
    "results/test-report.html",
    "results/test-report.pdf",
    "results/deployment-outputs.md"
)

foreach ($file in $resultsFiles) {
    if (Test-Path $file) {
        Remove-Item $file -Force
        Write-Host "✅ Removed: $file"
    }
}

# deployment-outputs.md holds live credentials/DNS/IPs for the last run -
# confirm it's actually gone rather than assuming Remove-Item succeeded.
if (Test-Path "results/deployment-outputs.md") {
    Write-Host "⚠️  results/deployment-outputs.md still present - remove manually before continuing"
}

Write-Host ""
Write-Host "Step 3: Resetting terraform configuration..."
Write-Host ""

if (Test-Path "terraform/terraform.tfvars") {
    Remove-Item "terraform/terraform.tfvars" -Force
    Write-Host "✅ Removed: terraform/terraform.tfvars"
}

if (Test-Path "terraform/terraform.tfvars.example") {
    Copy-Item "terraform/terraform.tfvars.example" "terraform/terraform.tfvars"
    Write-Host "✅ Reset: Created fresh terraform/terraform.tfvars from example"
}

Write-Host ""
Write-Host "Step 4: Removing terraform cache, state and generated key material..."
Write-Host ""

# terraform.tfstate.backup can retain prior sensitive values (e.g. the
# generated SSH private key in plaintext) even after a clean destroy leaves
# the primary state empty. Remove both explicitly rather than assuming
# `terraform destroy` scrubbed it.
$filesToRemove = @(
    "terraform/terraform.tfstate",
    "terraform/terraform.tfstate.backup",
    "terraform/tfplan",
    "terraform/TTL_AND_EXTENSION.txt"
)

foreach ($file in $filesToRemove) {
    if (Test-Path $file) {
        Remove-Item $file -Force
        Write-Host "✅ Removed: $file"
    }
}

Get-ChildItem -Path "terraform" -Filter "*.pem" -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item $_.FullName -Force
    Write-Host "✅ Removed: $($_.FullName)"
}

$dirsToRemove = @(
    "terraform/.terraform",
    "terraform/.terraform.lock.hcl"
)

foreach ($dir in $dirsToRemove) {
    if (Test-Path $dir) {
        Remove-Item $dir -Recurse -Force
        Write-Host "✅ Removed: $dir"
    }
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗"
Write-Host "║                   CLEANUP COMPLETE ✅                      ║"
Write-Host "╚════════════════════════════════════════════════════════════╝"
Write-Host ""
Write-Host "Repository is now clean and ready for a new test run:"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Edit test/AUTOMATED_TEST_TEMPLATE.md"
Write-Host "2. Add your source document link"
Write-Host "3. Say 'execute test' to Claude"
Write-Host ""
