# TheHive Case Management System - AWS EC2 Deployment

# Security Group for TheHive
resource "aws_security_group" "thehive" {
  name        = "thehive-sg"
  description = "Security group for TheHive case management"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "SSH access"
  }

  # TheHive Web Interface (port 9000)
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "TheHive Web Interface"
  }

  # Elasticsearch (port 9200) - for internal use but allow from anywhere
  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Elasticsearch"
  }

  # Outbound - allow all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "thehive-sg"
  }
}

# TheHive EC2 Instance
resource "aws_instance" "thehive" {
  ami                    = data.aws_ami.ubuntu_server.id
  instance_type          = var.thehive_instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = data.aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.thehive.id]

  associate_public_ip_address           = true
  monitoring                            = true
  instance_initiated_shutdown_behavior  = local.shutdown_behavior

  root_block_device {
    volume_size           = var.thehive_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "thehive-root"
    }
  }

  # TheHive initialization script.
  # file() not templatefile(): the script contains shell ${VAR} syntax that
  # Terraform would otherwise try to interpolate.
  # TTL prologue prepended so termination is scheduled before install work.
  user_data = base64encode(join("\n", [
    local.ttl_prologue,
    file("${path.module}/thehive-init.sh")
  ]))

  tags = {
    Name = "thehive-server"
  }

  depends_on = [aws_key_pair.main]
}

# Outputs for TheHive
output "thehive_instance_id" {
  description = "TheHive EC2 Instance ID"
  value       = aws_instance.thehive.id
}

output "thehive_public_ip" {
  description = "TheHive public IP address"
  value       = aws_instance.thehive.public_ip
}

output "thehive_public_dns" {
  description = "TheHive public DNS name"
  value       = aws_instance.thehive.public_dns
}

output "thehive_private_ip" {
  description = "TheHive private IP address"
  value       = aws_instance.thehive.private_ip
}

output "thehive_url" {
  description = "TheHive web interface URL"
  value       = "http://${aws_instance.thehive.public_dns}:9000"
}

output "thehive_elasticsearch_url" {
  description = "Elasticsearch API URL"
  value       = "http://${aws_instance.thehive.public_dns}:9200"
}

output "ssh_to_thehive" {
  description = "SSH command to connect to TheHive"
  value       = "ssh -i ${var.ssh_key_output_path}/wazuh-test-key.pem ubuntu@${aws_instance.thehive.public_dns}"
}
