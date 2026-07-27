#!/bin/bash

# Cleanup Test Files and Infrastructure
# This script cleans up after a test run

cat << 'EOF'
╔════════════════════════════════════════════════════════════╗
║          WAZUH TEST INFRASTRUCTURE CLEANUP                 ║
╚════════════════════════════════════════════════════════════╝
EOF

echo ""
read -p "This will destroy infrastructure and remove test results. Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Step 1: Destroying Terraform infrastructure..."
echo ""

cd terraform
if [ -f "terraform.tfvars" ]; then
    echo "Running: terraform destroy"
    terraform destroy -auto-approve
    if [ $? -eq 0 ]; then
        echo "✅ Infrastructure destroyed"
    else
        echo "⚠️  Terraform destroy completed with warnings"
    fi
else
    echo "⚠️  No terraform.tfvars found - skipping destroy"
fi

cd ..

echo ""
echo "Step 2: Removing test result files..."
echo ""

results_files=(
    "Results/test-implementation-steps.md"
    "Results/test-verdict.md"
    "Results/test-details.md"
    "Results/execution-log.txt"
)

for file in "${results_files[@]}"; do
    if [ -f "$file" ]; then
        rm -f "$file"
        echo "✅ Removed: $file"
    fi
done

echo ""
echo "Step 3: Resetting terraform configuration..."
echo ""

if [ -f "terraform/terraform.tfvars" ]; then
    rm -f "terraform/terraform.tfvars"
    echo "✅ Removed: terraform/terraform.tfvars"
fi

if [ -f "terraform/terraform.tfvars.example" ]; then
    cp "terraform/terraform.tfvars.example" "terraform/terraform.tfvars"
    echo "✅ Reset: Created fresh terraform/terraform.tfvars from example"
fi

echo ""
echo "Step 4: Removing terraform cache and state..."
echo ""

dirs_to_remove=(
    "terraform/.terraform"
)

for dir in "${dirs_to_remove[@]}"; do
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        echo "✅ Removed: $dir"
    fi
done

if [ -f "terraform/.terraform.lock.hcl" ]; then
    rm -f "terraform/.terraform.lock.hcl"
    echo "✅ Removed: terraform/.terraform.lock.hcl"
fi

cat << 'EOF'

╔════════════════════════════════════════════════════════════╗
║                   CLEANUP COMPLETE ✅                      ║
╚════════════════════════════════════════════════════════════╝

Repository is now clean and ready for a new test run:

Next steps:
1. Edit test/AUTOMATED_TEST_TEMPLATE.md
2. Add your Google Drive document link
3. Say 'execute test' to Claude

EOF
