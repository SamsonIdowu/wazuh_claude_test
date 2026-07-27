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
  region = var.aws_region
}

# Generate SSH key pair for EC2 instances
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.main.private_key_pem
  filename        = "${var.ssh_key_output_path}/wazuh-test-key.pem"
  file_permission = "0600"
}

# AWS key pair
resource "aws_key_pair" "main" {
  key_name   = "wazuh-test-key"
  public_key = tls_private_key.main.public_key_openssh

  tags = {
    Name = "wazuh-test-key"
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
  name        = "wazuh-server-sg"
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

  # Wazuh Agent communication
  ingress {
    from_port   = 1514
    to_port     = 1514
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Wazuh agent TCP"
  }

  ingress {
    from_port   = 1514
    to_port     = 1514
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Wazuh agent UDP"
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

  # Outbound - allow all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wazuh-server-sg"
  }
}

# Security Group for Agent Endpoint
resource "aws_security_group" "wazuh_agent" {
  name        = "wazuh-agent-sg"
  description = "Security group for Wazuh agent endpoint"
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

# Get Ubuntu 24.04 LTS AMI for Agent
data "aws_ami" "ubuntu_agent" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"]
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

  user_data = base64encode(templatefile("${path.module}/wazuh-server-init.sh", {
    wazuh_version = var.wazuh_version
  }))

  tags = {
    Name               = "wazuh-server"
    Purpose            = "EOL Detection Testing"
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

  monitoring = true

  user_data = base64encode(templatefile("${path.module}/wazuh-agent-init.sh", {
    wazuh_server_ip = aws_instance.wazuh_server.private_ip
    wazuh_version  = var.wazuh_version
  }))

  tags = {
    Name               = "wazuh-agent"
    Purpose            = "EOL Detection Test Endpoint"
    TTL_Minutes        = var.resource_ttl_minutes
    AutoTermination    = var.enable_auto_termination
    CreatedAt          = timestamp()
  }

  depends_on = [aws_instance.wazuh_server]
}
