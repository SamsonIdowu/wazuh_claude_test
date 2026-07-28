output "wazuh_server_public_dns" {
  description = "Wazuh server public DNS name"
  value       = aws_instance.wazuh_server.public_dns
}

output "wazuh_server_public_ip" {
  description = "Wazuh server public IP address"
  value       = aws_instance.wazuh_server.public_ip
}

output "wazuh_server_private_ip" {
  description = "Wazuh server private IP address"
  value       = aws_instance.wazuh_server.private_ip
}

output "wazuh_agent_public_dns" {
  description = "Wazuh agent public DNS name"
  value       = aws_instance.wazuh_agent.public_dns
}

output "wazuh_agent_public_ip" {
  description = "Wazuh agent public IP address"
  value       = aws_instance.wazuh_agent.public_ip
}

output "wazuh_agent_private_ip" {
  description = "Wazuh agent private IP address"
  value       = aws_instance.wazuh_agent.private_ip
}

output "ssh_key_path" {
  description = "Path to SSH private key"
  value       = local_file.private_key.filename
}

output "ssh_to_wazuh_server" {
  description = "SSH command to connect to Wazuh server"
  value       = "ssh -i ${local_file.private_key.filename} ubuntu@${aws_instance.wazuh_server.public_dns}"
}

output "ssh_to_wazuh_agent" {
  description = "SSH command to connect to Wazuh agent"
  value       = "ssh -i ${local_file.private_key.filename} ubuntu@${aws_instance.wazuh_agent.public_dns}"
}

output "wazuh_dashboard_url" {
  description = "Wazuh Dashboard URL"
  value       = "https://${aws_instance.wazuh_server.public_dns}"
}

output "wazuh_api_url" {
  description = "Wazuh API URL"
  value       = "https://${aws_instance.wazuh_server.public_dns}:55000"
}

output "wazuh_indexer_url" {
  description = "Wazuh indexer URL (opened for external SOAR/API access)"
  value       = "https://${aws_instance.wazuh_server.public_dns}:9200"
}

# TheHive runs on the same instance as the Wazuh agent, per the infrastructure
# guide - there is no separate TheHive instance.
output "thehive_url" {
  description = "TheHive web interface URL"
  value       = "http://${aws_instance.wazuh_agent.public_dns}:9000/thehive/login"
}

output "wazuh_server_instance_id" {
  description = "Wazuh server instance ID"
  value       = aws_instance.wazuh_server.id
}

output "wazuh_agent_instance_id" {
  description = "Wazuh agent instance ID"
  value       = aws_instance.wazuh_agent.id
}

output "resource_ttl_minutes" {
  description = "Time-to-live for resources in minutes"
  value       = var.resource_ttl_minutes
}

output "auto_termination_enabled" {
  description = "Whether auto-termination is enabled"
  value       = var.enable_auto_termination
}

output "ttl_extension_instructions" {
  description = "Instructions to extend TTL"
  value       = <<-EOT
⏱️  AUTO-TERMINATION COUNTDOWN: ${var.resource_ttl_minutes} minutes

TO EXTEND THE TTL:
  1. Edit terraform/terraform.tfvars
  2. Change: resource_ttl_minutes = ${var.resource_ttl_minutes + 60}
  3. Run: terraform apply

TO DISABLE AUTO-TERMINATION:
  1. Edit terraform/terraform.tfvars
  2. Add: enable_auto_termination = false
  3. Run: terraform apply

TO CLEANUP IMMEDIATELY:
  Run: terraform destroy
EOT
}
