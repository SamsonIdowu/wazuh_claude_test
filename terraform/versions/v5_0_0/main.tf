# Wazuh 5.0.0 Server Infrastructure
#
# Based on 4.14.6 deployment with 5.0-specific changes:
# - Installation branch updated to 5.0
# - Potential API endpoint differences (to be verified during testing)
# - Same core installation approach (quickstart installer)
# - Same TTL enforcement mechanism
#
# NOTE: This module is activated via wazuh_major_version = 5 in terraform.tfvars

locals {
  wazuh_version       = var.wazuh_version
  wazuh_branch        = var.wazuh_install_branch  # "5.0" for 5.0.x releases
  install_timeout     = 1800                       # 30 minutes (same as 4.14.6)
}

# Security Group for Wazuh Server (5.0.0)
resource "aws_security_group" "wazuh_server_v5" {
  name        = "wazuh-server-v5-sg"
  description = "Security group for Wazuh 5.0.0 server"
  vpc_id      = data.aws_vpc.default.id

  # SSH from your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "SSH access"
  }

  # Wazuh Agent communication (TCP)
  ingress {
    from_port   = 1514
    to_port     = 1514
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Wazuh agent TCP"
  }

  # Wazuh Agent communication (UDP)
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

  # Indexer (may need external access in 5.0)
  # NOTE: RESEARCH - verify if this is needed in 5.0 (was localhost-only in 4.14.6)
  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Opensearch/Indexer (may be localhost-only)"
  }

  # Outbound - allow all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wazuh-server-v5-sg"
  }
}

# Get Ubuntu 22.04 LTS AMI for Wazuh 5.0 Server
data "aws_ami" "ubuntu_server_v5" {
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

# Wazuh 5.0.0 Server EC2 Instance
resource "aws_instance" "wazuh_server_v5" {
  ami                    = data.aws_ami.ubuntu_server_v5.id
  instance_type          = var.wazuh_server_instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = data.aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.wazuh_server_v5.id]

  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.wazuh_server_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "wazuh-server-v5-root"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring = true

  # TTL enforcement: terminate on shutdown (not stop)
  instance_initiated_shutdown_behavior = local.shutdown_behavior

  user_data = base64encode(templatefile("${path.module}/wazuh-server-init-v5.sh", {
    wazuh_version           = local.wazuh_version
    wazuh_branch            = local.wazuh_branch
    ttl_prologue            = local.ttl_prologue
    resource_ttl_minutes    = var.resource_ttl_minutes
    enable_auto_termination = var.enable_auto_termination
  }))

  tags = {
    Name               = "wazuh-server-v5"
    Version            = "5.0.0"
    Purpose            = "EOL Detection Testing"
    TTL_Minutes        = var.resource_ttl_minutes
    AutoTermination    = var.enable_auto_termination
    CreatedAt          = timestamp()
  }

  depends_on = [aws_security_group.wazuh_server_v5]
}

# Outputs for this version
locals {
  wazuh_server_v5_outputs = {
    public_dns  = aws_instance.wazuh_server_v5.public_dns
    public_ip   = aws_instance.wazuh_server_v5.public_ip
    private_ip  = aws_instance.wazuh_server_v5.private_ip
    instance_id = aws_instance.wazuh_server_v5.id
  }
}
