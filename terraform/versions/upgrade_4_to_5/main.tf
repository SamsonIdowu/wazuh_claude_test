# Upgrade Testing Scenario: 4.14.6 → 5.0.0
#
# This module deploys Wazuh 4.14.6 as a baseline for testing the upgrade to 5.0.0.
# After deployment, users manually run the upgrade script to test the migration path.

module "base_4_14_6" {
  source = "../v4_14_6"

  # Use 4.14.6 as baseline
  wazuh_version           = var.wazuh_version
  wazuh_branch            = "4.14"
  instance_type           = "t3.xlarge"
  ami_filter              = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
  environment             = var.environment
  wazuh_test_key_pair     = var.wazuh_test_key_pair
  availability_zone       = var.availability_zone
  resource_ttl_minutes    = var.resource_ttl_minutes
  common_tags             = var.common_tags

  # Provide context that this is an upgrade test
  common_tags = merge(
    var.common_tags,
    {
      "TestScenario" = "upgrade_4_to_5"
      "Purpose"      = "Baseline for 4.14.6 to 5.0.0 upgrade testing"
      "Notes"        = "After deployment, manually upgrade server to 5.0.0"
    }
  )
}

# Output server details for manual upgrade
output "wazuh_server_public_dns" {
  description = "Public DNS name of Wazuh server (for SSH access during upgrade)"
  value       = module.base_4_14_6.wazuh_server_public_dns
}

output "wazuh_server_public_ip" {
  description = "Public IP address of Wazuh server"
  value       = module.base_4_14_6.wazuh_server_public_ip
}

output "ssh_connection_string" {
  description = "SSH command to connect to server"
  value       = "ssh -i ${var.wazuh_test_key_pair}.pem ubuntu@${module.base_4_14_6.wazuh_server_public_dns}"
}

output "upgrade_instructions" {
  description = "Instructions for upgrading to 5.0.0"
  value       = <<-EOT
    WAZUH 4.14.6 BASELINE DEPLOYED
    ═════════════════════════════════════════════════════════════════

    Next: Upgrade to 5.0.0

    1. SSH to server:
       ${var.wazuh_test_key_pair != "" ? "ssh -i ${var.wazuh_test_key_pair}.pem ubuntu@${module.base_4_14_6.wazuh_server_public_dns}" : "ssh -i wazuh-test-key.pem ubuntu@<server_dns>"}

    2. Verify 4.14.6 running:
       sudo /var/ossec/bin/wazuh-control info

    3. Create backup:
       sudo tar -czf /root/wazuh-4.14.6-backup.tar.gz \
         /var/ossec /etc/wazuh-* /root/wazuh-install-files

    4. Download upgrade script (verify HTTP 200):
       curl -sO https://packages.wazuh.com/5.0/wazuh-upgrade.sh

    5. Run upgrade:
       sudo bash ./wazuh-upgrade.sh

    6. Verify 5.0.0:
       sudo /var/ossec/bin/wazuh-control info

    7. Test agent re-enrollment:
       sudo /var/ossec/bin/agent_control -l

    See: test/UPGRADE_TEST_TEMPLATE.md for detailed procedure
    ═════════════════════════════════════════════════════════════════
  EOT
}

output "estimated_upgrade_duration" {
  description = "Estimated time for upgrade process"
  value       = "Baseline: 45 minutes | Upgrade: 30 minutes | Testing: 20 minutes | Total: ~95 minutes"
}

output "estimated_cost" {
  description = "Estimated cost for upgrade testing"
  value       = "t3.xlarge, ~1.5 hours = ~$0.44"
}
