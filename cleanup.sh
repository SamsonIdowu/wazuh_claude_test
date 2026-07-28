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
echo "Step 1b: Verifying teardown against AWS (don't trust the exit code alone)..."
echo ""

region=$(grep -oE 'aws_region\s*=\s*"[^"]+"' terraform/terraform.tfvars 2>/dev/null | grep -oE '"[^"]+"' | tr -d '"')
region=${region:-us-east-1}
profile=$(grep -oE 'aws_profile\s*=\s*"[^"]+"' terraform/terraform.tfvars 2>/dev/null | grep -oE '"[^"]+"' | tr -d '"')
profile=${profile:-wazuh}

if command -v aws >/dev/null 2>&1; then
    remaining=$(aws ec2 describe-instances --region "$region" --profile "$profile" \
        --filters "Name=tag:Name,Values=wazuh-server,wazuh-agent,thehive-server" \
                  "Name=instance-state-name,Values=pending,running,stopping,stopped" \
        --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null)
    if [ -n "$remaining" ]; then
        echo "⚠️  Instances still present in AWS: $remaining"
        echo "    Investigate before assuming this cleanup is complete."
    else
        echo "✅ Confirmed: no wazuh-server/wazuh-agent/thehive-server instances remain in $region"
    fi
else
    echo "⚠️  aws CLI not found - could not verify against AWS. Check the console manually."
fi

echo ""
echo "Step 2: Removing test result files..."
echo ""

results_files=(
    "results/test-implementation-steps.md"
    "results/test-verdict.md"
    "results/execution-log.txt"
    "results/test-report.html"
    "results/test-report.pdf"
    "results/deployment-outputs.md"
)

for file in "${results_files[@]}"; do
    if [ -f "$file" ]; then
        rm -f "$file"
        echo "✅ Removed: $file"
    fi
done

# deployment-outputs.md holds live credentials/DNS/IPs for the last run -
# confirm it's actually gone rather than assuming rm succeeded.
if [ -f "results/deployment-outputs.md" ]; then
    echo "⚠️  results/deployment-outputs.md still present - remove manually before continuing"
fi

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
echo "Step 4: Removing terraform cache, state and generated key material..."
echo ""

# terraform.tfstate.backup can retain prior sensitive values (e.g. the
# generated SSH private key in plaintext) even after a clean destroy leaves
# the primary state empty. Remove both explicitly rather than assuming
# `terraform destroy` scrubbed it.
files_to_remove=(
    "terraform/terraform.tfstate"
    "terraform/terraform.tfstate.backup"
    "terraform/tfplan"
    "terraform/TTL_AND_EXTENSION.txt"
)

for file in "${files_to_remove[@]}"; do
    if [ -f "$file" ]; then
        rm -f "$file"
        echo "✅ Removed: $file"
    fi
done

rm -f terraform/*.pem 2>/dev/null

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
2. Add your source document link
3. Say 'execute test' to Claude

EOF
