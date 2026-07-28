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
    Name = "wazuh-server-sg"
  }
}

# Security Group for the combined Wazuh agent + TheHive endpoint
resource "aws_security_group" "wazuh_agent" {
  name        = "wazuh-agent-sg"
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

  # Official Wazuh quickstart all-in-one install:
  # https://documentation.wazuh.com/current/quickstart.html
  user_data = base64encode(<<-EOF
${local.ttl_prologue}
set -euxo pipefail
exec > >(tee -a /var/log/wazuh-install.log) 2>&1

WAZUH_BRANCH="$(echo "${var.wazuh_version}" | cut -d. -f1,2)"
cd /root
curl -sO "https://packages.wazuh.com/$${WAZUH_BRANCH}/wazuh-install.sh"
bash ./wazuh-install.sh -a -i

# The quickstart installer binds the indexer to network.host: 127.0.0.1, so
# it is unreachable externally even with the security group open on 9200 -
# confirmed twice now, not a one-off. Rebind and confirm it comes back active
# before declaring the deployment ready.
sed -i 's|^network.host: .*|network.host: "0.0.0.0"|' /etc/wazuh-indexer/opensearch.yml
systemctl restart wazuh-indexer
for i in $(seq 1 12); do
  systemctl is-active --quiet wazuh-indexer && break
  sleep 5
done

# Persist generated admin credentials for retrieval
tar -xf wazuh-install-files.tar -C /root 2>/dev/null || true
echo "WAZUH_INSTALL_COMPLETE=$(date -Is)" > /root/WAZUH_READY
EOF
  )

  tags = {
    Name               = "wazuh-server"
    Purpose            = "EOL Detection Testing"
    TTL_Minutes        = var.resource_ttl_minutes
    AutoTermination    = var.enable_auto_termination
    CreatedAt          = timestamp()
  }

  depends_on = [aws_security_group.wazuh_server]
}

# Combined Wazuh Agent + TheHive EC2 Instance
#
# Per the infrastructure guide, TheHive runs on the SAME Ubuntu 24 endpoint as
# the Wazuh agent, not on a dedicated instance. user_data runs three chunks in
# sequence in a single boot script:
#   1. TTL prologue (schedules self-termination first, per REAL TTL ENFORCEMENT above)
#   2. wazuh-agent-init.sh (templatefile - needs wazuh_server_ip/wazuh_version
#      interpolated by Terraform)
#   3. thehive-init.sh (file() - contains literal shell ${VAR} that must survive
#      Terraform untouched; see that file's own header for why upstream's
#      StrangeBee compose is used instead of a hand-written one)
# A bare "#!/bin/bash" appearing after the first line of a script is just a
# comment to bash, so concatenating three self-contained scripts this way is
# safe - each one's `set -e`/`exec > >(tee ...)` applies from that point on.
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

  user_data = base64encode(join("\n", [
    local.ttl_prologue,
    templatefile("${path.module}/wazuh-agent-init.sh", {
      wazuh_server_ip = aws_instance.wazuh_server.private_ip
      wazuh_version   = var.wazuh_version
    }),
    file("${path.module}/thehive-init.sh")
  ]))

  tags = {
    Name            = "wazuh-agent"
    Purpose         = "Wazuh Agent + TheHive Endpoint"
    TTL_Minutes     = var.resource_ttl_minutes
    AutoTermination = var.enable_auto_termination
    CreatedAt       = timestamp()
  }

  depends_on = [aws_instance.wazuh_server]
}
