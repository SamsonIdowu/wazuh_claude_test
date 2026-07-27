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
Write-Host "Step 2: Removing test result files..."
Write-Host ""

$resultsFiles = @(
    "Results/test-implementation-steps.md",
    "Results/test-verdict.md",
    "Results/test-details.md",
    "Results/execution-log.txt"
)

foreach ($file in $resultsFiles) {
    if (Test-Path $file) {
        Remove-Item $file -Force
        Write-Host "✅ Removed: $file"
    }
}

Write-Host ""
Write-Host "Step 3: Resetting terraform configuration..."
Write-Host ""

if (Test-Path "terraform/terraform.tfvars") {
    Remove-Item "terraform/terraform.tfvars" -Force
    Write-Host "✅ Removed: terraform/terraform.tfvars"
}

if (Test-Path "terraform.tfvars.example") {
    Copy-Item "terraform.tfvars.example" "terraform/terraform.tfvars"
    Write-Host "✅ Reset: Created fresh terraform/terraform.tfvars from example"
}

Write-Host ""
Write-Host "Step 4: Removing terraform cache and state..."
Write-Host ""

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
Write-Host "2. Add your Google Drive document link"
Write-Host "3. Say 'execute test' to Claude"
Write-Host ""
