terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# ---------------------------------------------------------------------------
# REAL TTL ENFORCEMENT
#
# History: resource_ttl_minutes and enable_auto_termination used to produce only
# a local text file and two EC2 tags. Nothing enforced them. A test run was left
# running for 17 hours (~$4.92) because the tags and docs claimed
# "auto-termination enabled" while no mechanism existed.
#
# Enforcement now has two parts, and BOTH are required:
#   1. `shutdown -h +N` scheduled as the FIRST action in user_data, before any
#      install work, so a failed or hung install still terminates on time.
#   2. instance_initiated_shutdown_behavior = "terminate", so the shutdown
#      TERMINATES rather than stops the instance. Without this the instance
#      merely stops and its EBS volumes keep billing.
#
# This is deliberately dumb and local: no Lambda, no scheduler, nothing external
# that can silently fail. The instance kills itself.
# ---------------------------------------------------------------------------
locals {
  # Heredocs cannot be embedded directly in a ternary, so build both branches
  # separately and select between them.
  ttl_prologue_enabled = <<-EOT
    #!/bin/bash
    # --- TTL self-termination (${var.resource_ttl_minutes} min) ---
    # Scheduled first so it survives any later failure in this script.
    /sbin/shutdown -h +${var.resource_ttl_minutes} "Auto-terminating after ${var.resource_ttl_minutes}min TTL" || true
    echo "TTL_SCHEDULED=$(date -Is) MINUTES=${var.resource_ttl_minutes}" > /root/TTL_SCHEDULED
    # --- end TTL ---
  EOT

  ttl_prologue_disabled = "#!/bin/bash\n# TTL enforcement disabled (enable_auto_termination = false)\n"

  ttl_prologue = var.enable_auto_termination ? local.ttl_prologue_enabled : local.ttl_prologue_disabled

  # Shutdown must terminate, not stop, or EBS volumes keep costing money.
  shutdown_behavior = var.enable_auto_termination ? "terminate" : "stop"
}

# Generate SSH key pair for EC2 instances
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key locally
#
# file_permission = "0600" is a no-op on Windows: local_file only sets POSIX
# mode bits, which Windows has none of. The real gate on Windows is the file's
# ACL, which by default inherits from the parent folder - on this machine that
# inheritance grants Full Control to SYSTEM, Administrators, AND an unrelated
# "remote" account. OpenSSH's Windows client refuses to load a key if ANY
# account other than the owner can read it, so every fresh `terraform apply`
# produced a key ssh immediately rejected with "Bad permissions" /
# "UNPROTECTED PRIVATE KEY FILE". The provisioner below strips inherited ACLs
# and grants read-only access to the current user only, right after the key
# is written, so this can't recur.
resource "local_file" "private_key" {
  content         = tls_private_key.main.private_key_pem
  filename        = "${var.ssh_key_output_path}/wazuh-test-key.pem"
  file_permission = "0600"

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = "icacls '${self.filename}' /inheritance:r /grant:r \"$($env:USERNAME):(R)\""
  }
}

# AWS key pair
# Named per-version: a key pair name is unique account+region-wide, so two
# concurrent tests sharing this account collide on a fixed name (this, plus
# identical fixed Name tags on the instances/SGs below, caused one session's
# `terraform destroy`/cleanup to silently delete another session's
# identically-named resources during PoC-guide testing on 2026-08-06).
# key_name is ForceNew on aws_instance, so this does force every instance
# referencing it to replace once - a one-time cost paid already in this run.
resource "aws_key_pair" "main" {
  key_name   = "wazuh-test-key-${var.wazuh_version}"
  public_key = tls_private_key.main.public_key_openssh

  tags = {
    Name = "wazuh-test-key-${var.wazuh_version}"
  }
}

# Auto-termination script for 1-hour TTL
resource "local_file" "ttl_info" {
  filename = "${var.ssh_key_output_path}/TTL_AND_EXTENSION.txt"
  content  = <<-EOT
╔════════════════════════════════════════════════════════════════════╗
║         WAZUH TEST INFRASTRUCTURE - AUTO-TERMINATION INFO          ║
╚════════════════════════════════════════════════════════════════════╝

⏱️  DEFAULT TTL: ${var.resource_ttl_minutes} minutes

📅 DEPLOYMENT TIME: ${timestamp()}
🛑 AUTO-TERMINATION TIME: In ${var.resource_ttl_minutes} minutes

═══════════════════════════════════════════════════════════════════════

⚠️  IMPORTANT: Your resources will AUTO-TERMINATE in ${var.resource_ttl_minutes} minutes!

To PREVENT TERMINATION or EXTEND the TTL:

Option 1: EXTEND (Add more time)
─────────────────────────────────
  Edit terraform/terraform.tfvars and change:
    resource_ttl_minutes = ${var.resource_ttl_minutes + 60}

  Then run:
    terraform apply

  This will extend the termination by another hour.

Option 2: DISABLE AUTO-TERMINATION (Keep resources running)
────────────────────────────────────────────────────────────
  Edit terraform/terraform.tfvars and add:
    enable_auto_termination = false

  Then run:
    terraform apply

Option 3: IMMEDIATE TERMINATION (Clean up early)
─────────────────────────────────────────────────
  Run:
    terraform destroy

═══════════════════════════════════════════════════════════════════════

⏳ COUNTDOWN:
  • Resources will be terminated automatically
  • No manual action required if you want cleanup
  • Respond within ${var.resource_ttl_minutes} minutes to extend or disable

═══════════════════════════════════════════════════════════════════════
EOT
}

# Security Group for Wazuh Server
resource "aws_security_group" "wazuh_server" {
  name        = "wazuh-server-sg-${var.wazuh_version}"
  description = "Security group for Wazuh server"
  vpc_id      = data.aws_vpc.default.id

  # SSH from your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "SSH access"
  }

  # Wazuh agent communication and enrollment are VPC-internal only: the agent
  # reaches the manager over private IPs (agent 172.31.x -> manager private IP),
  # so these ports must not be exposed to the internet.
  ingress {
    from_port   = 1514
    to_port     = 1514
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
    description = "Wazuh agent TCP (VPC private only)"
  }

  ingress {
    from_port   = 1514
    to_port     = 1514
    protocol    = "udp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
    description = "Wazuh agent UDP (VPC private only)"
  }

  # Agent enrollment (authd). Without this the agent logs
  # "Requesting a key from server" and never registers - 1514 alone is not
  # enough, registration happens on 1515.
  ingress {
    from_port   = 1515
    to_port     = 1515
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
    description = "Wazuh agent enrollment authd (VPC private only)"
  }

  # Wazuh Dashboard (HTTPS)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS Dashboard"
  }

  # Wazuh API
  ingress {
    from_port   = 55000
    to_port     = 55000
    protocol    = "tcp"
    cidr_blocks = var.allowed_api_cidrs
    description = "Wazuh API"
  }

  # Wazuh indexer. Required only because Shuffle *Cloud* executes workflow nodes
  # outside this VPC and must query the indexer directly.
  # SECURITY: this exposes Elasticsearch to the internet. It is HTTP-basic
  # authenticated, but for anything beyond a TTL-limited test either restrict
  # this to Shuffle's egress ranges or run Shuffle self-hosted inside the VPC
  # and drop this rule entirely.
  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = var.allowed_api_cidrs
    description = "Wazuh indexer (Shuffle Cloud access)"
  }

  # Outbound - allow all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wazuh-server-sg-${var.wazuh_version}"
  }

  # Other security groups reference this one by ID (e.g. the Windows victim
  # endpoint's agent-comms rule). Without create_before_destroy, renaming
  # this SG's `name` makes Terraform destroy-then-create, and the destroy
  # fails with DependencyViolation because the referencing SG hasn't been
  # updated yet - discovered while fixing the account-wide Name collision.
  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for the combined Wazuh agent + TheHive endpoint
resource "aws_security_group" "wazuh_agent" {
  name        = "wazuh-agent-sg-${var.wazuh_version}"
  description = "Security group for Wazuh agent + TheHive endpoint"
  vpc_id      = data.aws_vpc.default.id

  # SSH from your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "SSH access"
  }

  # Wazuh agent communication to manager
  ingress {
    from_port       = 1514
    to_port         = 1514
    protocol        = "tcp"
    security_groups = [aws_security_group.wazuh_server.id]
    description     = "Wazuh agent from manager"
  }

  # TheHive web interface - publicly accessible per the infrastructure guide.
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "TheHive web interface"
  }

  # Outbound - allow all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wazuh-agent-sg"
  }
}

# Data source for default VPC
data "aws_vpc" "default" {
  default = true
}

# Data source for default subnet
data "aws_subnet" "default" {
  availability_zone = data.aws_availability_zones.available.names[0]
  vpc_id            = data.aws_vpc.default.id
  default_for_az    = true
}

# Data source for AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Get Ubuntu 22.04 LTS AMI for Wazuh Server
data "aws_ami" "ubuntu_server" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Get Ubuntu 24.04 LTS (noble) AMI for the agent+TheHive endpoint, per the
# infrastructure guide's explicit "Ubuntu 24 endpoint" requirement.
# Canonical's 24.04 AMIs live under hvm-ssd-gp3, not the plain hvm-ssd path
# used for 22.04 above - a glob without the wildcard after hvm-ssd returns no
# results and looks like "24.04 isn't available in this region", which it is.
data "aws_ami" "ubuntu_agent" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Wazuh Server EC2 Instance
resource "aws_instance" "wazuh_server" {
  ami                    = data.aws_ami.ubuntu_server.id
  instance_type          = var.wazuh_server_instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = data.aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.wazuh_server.id]

  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.wazuh_server_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "wazuh-server-root"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring = true

  instance_initiated_shutdown_behavior = local.shutdown_behavior

  user_data = base64encode(templatefile("${path.module}/wazuh-server-init.sh", {
    ttl_prologue           = local.ttl_prologue
    wazuh_version          = var.wazuh_version
    resource_ttl_minutes   = var.resource_ttl_minutes
  }))

  tags = {
    # Suffixed with wazuh_version: a generic "wazuh-server" Name tag collides
    # across concurrent tests sharing this AWS account. This repo's own
    # documented cleanup commands (README.md, TTL_AND_AUTO_TERMINATION.md)
    # filter EC2 by tag:Name, not by instance ID/state file, so one session's
    # teardown silently terminates another session's identically-tagged
    # instance too - this happened during PoC-guide testing on 2026-08-06.
    Name               = "wazuh-server-${var.wazuh_version}"
    Purpose            = "Wazuh Server"
    TTL_Minutes        = var.resource_ttl_minutes
    AutoTermination    = var.enable_auto_termination
    CreatedAt          = timestamp()
  }

  depends_on = [aws_security_group.wazuh_server]
}

# Wazuh Agent EC2 Instance
resource "aws_instance" "wazuh_agent" {
  ami                    = data.aws_ami.ubuntu_agent.id
  instance_type          = var.agent_instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = data.aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.wazuh_agent.id]

  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.agent_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "wazuh-agent-root"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring                           = true
  instance_initiated_shutdown_behavior = local.shutdown_behavior

  user_data = base64encode(templatefile("${path.module}/wazuh-agent-init.sh", {
    ttl_prologue    = local.ttl_prologue
    wazuh_server_ip = aws_instance.wazuh_server.private_ip
    wazuh_version   = var.wazuh_version
  }))

  tags = {
    Name            = "wazuh-agent-${var.wazuh_version}"
    Purpose         = "Wazuh Agent"
    TTL_Minutes     = var.resource_ttl_minutes
    AutoTermination = var.enable_auto_termination
    CreatedAt       = timestamp()
  }

  depends_on = [aws_instance.wazuh_server]
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 5: OUTPUTS — COST TRACKING & DEPLOYMENT INFORMATION
# ═══════════════════════════════════════════════════════════════════════════

output "wazuh_server_public_ip" {
  description = "Public IP address of Wazuh server"
  value       = aws_instance.wazuh_server.public_ip
}

output "wazuh_server_public_dns" {
  description = "Public DNS name of Wazuh server"
  value       = aws_instance.wazuh_server.public_dns
}

output "wazuh_server_private_ip" {
  description = "Private IP address of Wazuh server (for agent communication)"
  value       = aws_instance.wazuh_server.private_ip
}

output "wazuh_agent_public_ip" {
  description = "Public IP address of Wazuh agent (+ TheHive endpoint)"
  value       = aws_instance.wazuh_agent.public_ip
}

output "wazuh_agent_public_dns" {
  description = "Public DNS name of Wazuh agent instance"
  value       = aws_instance.wazuh_agent.public_dns
}

output "ssh_to_wazuh_server" {
  description = "SSH command to connect to Wazuh server"
  value       = "ssh -i wazuh-test-key.pem ubuntu@${aws_instance.wazuh_server.public_dns}"
}

output "ssh_to_wazuh_agent" {
  description = "SSH command to connect to Wazuh agent"
  value       = "ssh -i wazuh-test-key.pem ubuntu@${aws_instance.wazuh_agent.public_dns}"
}

output "dashboard_url" {
  description = "URL to access Wazuh dashboard"
  value       = "https://${aws_instance.wazuh_server.public_dns}"
}

output "api_endpoint" {
  description = "Wazuh API endpoint"
  value       = "https://${aws_instance.wazuh_server.public_dns}:55000/api"
}

output "thehive_url" {
  description = "URL to access TheHive interface"
  value       = "http://${aws_instance.wazuh_agent.public_dns}:9000"
}

# ═══════════════════════════════════════════════════════════════════════════
# COST TRACKING
# ═══════════════════════════════════════════════════════════════════════════

output "estimated_hourly_cost" {
  description = "Estimated hourly cost based on instance types"
  value = {
    wazuh_server     = "t3.xlarge: $0.1664/hour"
    wazuh_agent      = "t3.large: $0.0832/hour"
    ebs_gp3_volumes  = "~$0.10/hour (server 30GB + agent 20GB)"
    total_per_hour   = "~$0.35/hour"
  }
}

output "estimated_deployment_cost" {
  description = "Estimated cost for full infrastructure deployment (45 minutes)"
  value = {
    deployment_time_minutes = 45
    wazuh_server            = "$0.125 (45 min)"
    wazuh_agent             = "$0.062 (45 min)"
    ebs_volumes             = "$0.075 (45 min)"
    total_estimated         = "$0.262 (~45 minutes at default TTL)"
  }
}

output "ttl_configuration" {
  description = "Time-To-Live and auto-termination configuration"
  value = {
    ttl_minutes           = var.resource_ttl_minutes
    auto_termination      = var.enable_auto_termination
    termination_behavior  = local.shutdown_behavior
    deployment_timestamp  = timestamp()
    auto_cleanup_time     = "In ${var.resource_ttl_minutes} minutes"
    cost_impact_of_ttl    = "Ensures instances terminate automatically, preventing accidental runaway costs"
  }
}

output "cost_optimization_tips" {
  description = "Tips to optimize testing costs"
  value = [
    "1. Default TTL of 240 minutes (~$0.84) - adjust via terraform.tfvars",
    "2. Extend TTL if testing takes longer (edit resource_ttl_minutes and re-apply)",
    "3. Use 'terraform destroy' immediately if done testing to avoid unnecessary charges",
    "4. For cost-sensitive tests, use smaller instance types (t3.medium = ~$0.04/hour)",
    "5. Monitor AWS console for any left-over instances (TTL failures are rare but possible)",
    "6. See: test/TTL_AND_AUTO_TERMINATION.md for detailed TTL configuration"
  ]
}

# ═══════════════════════════════════════════════════════════════════════════
# DEPLOYMENT INFORMATION
# ═══════════════════════════════════════════════════════════════════════════

output "wazuh_version" {
  description = "Deployed Wazuh version"
  value       = var.wazuh_version
}

output "infrastructure_summary" {
  description = "Summary of deployed infrastructure"
  value = {
    wazuh_server = {
      instance_type  = var.wazuh_server_instance_type
      ami            = "Ubuntu 22.04 LTS"
      volume_size    = "${var.wazuh_server_volume_size}GB"
      services       = ["wazuh-manager", "wazuh-indexer", "wazuh-dashboard"]
      public_access  = "Dashboard (HTTPS 443), API (55000), SSH (22)"
    }
    wazuh_agent = {
      instance_type   = var.agent_instance_type
      ami             = "Ubuntu 24.04 LTS"
      volume_size     = "${var.agent_volume_size}GB"
      services        = ["wazuh-agent"]
      public_access   = "SSH (22)"
      internal_access = "Manager communication (1514, 1515)"
    }
    networking = {
      vpc         = "Default VPC"
      security    = "SSH restricted, agent/manager comms VPC-only"
      encryption  = "EBS volumes encrypted with AWS KMS"
    }
  }
}

output "next_steps" {
  description = "Recommended next steps after deployment"
  value = [
    "1. Retrieve credentials: ssh -i wazuh-test-key.pem ubuntu@${aws_instance.wazuh_server.public_dns}",
    "                         sudo tar -xOf /root/wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt",
    "",
    "2. Access Wazuh Dashboard: https://${aws_instance.wazuh_server.public_dns}",
    "",
    "3. Verify agent enrolled: On server: sudo /var/ossec/bin/agent_control -l",
    "",
    "4. Check deployment logs: ssh -i wazuh-test-key.pem ubuntu@${aws_instance.wazuh_server.public_dns} 'tail -f /var/log/wazuh-install.log'",
    "",
    "5. Extend TTL if needed: Edit terraform.tfvars resource_ttl_minutes and run 'terraform apply'",
    "",
    "6. Cleanup when done: terraform destroy"
  ]
}

output "documentation_references" {
  description = "Links to relevant documentation"
  value = {
    main_readme     = "README.md - Project overview"
    architecture    = "ARCHITECTURE_CORRECTION.md - Repository structure and cleanup procedures"
    agent_handoff   = "AGENT_HANDOFF.md - Guide for agents running tests"
    ttl_config      = "test/TTL_AND_AUTO_TERMINATION.md - TTL enforcement details"
  }
}
