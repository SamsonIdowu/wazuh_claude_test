# ---------------------------------------------------------------------------
# Wazuh 5.0 "Wazuh indexer cluster" documentation test — topology
#
# Pass 4 of this document. The three previous passes all needed the same base
# shape, so it is captured here rather than re-derived:
#
#   indexer-1..N   distributed indexer cluster (N=3 to start; raise
#                  cluster_indexer_count to 4 to exercise the documented
#                  "add a node" flow WITHOUT replacing indexer-1..3)
#   manager        separate wazuh-manager node (the doc's main flow)
#   dashboard      separate wazuh-dashboard node
#   allinone       single-node install, later scaled to 2 nodes
#   allinone-2     the node the all-in-one is upscaled with
#
# Provider, network, SSH key and the TTL prologue live in main.tf. This root is
# deliberately separate from ../main.tf's baseline single-node stack.
#
# No user_data beyond the TTL prologue: every install step in this test must be
# run by hand exactly as the document writes it. Pre-provisioning Wazuh here
# would defeat the entire point of the test.
# ---------------------------------------------------------------------------

variable "cluster_indexer_count" {
  description = "Number of wazuh-indexer nodes. Start at 3; raise to 4 to test the documented add-a-node procedure, then drop back to 3 for remove-a-node."
  type        = number
  default     = 3
}

variable "cluster_create_allinone" {
  description = "Also build the single-node all-in-one host plus the second node it gets upscaled with."
  type        = bool
  default     = true
}

variable "cluster_indexer_instance_type" {
  description = "Indexer nodes. The indexer ships a fixed -Xms1g/-Xmx1g heap regardless of machine size, so extra RAM here is headroom for the OS and for the documented tuning step, not an automatic fix."
  type        = string
  default     = "t3.large"
}

variable "cluster_manager_instance_type" {
  type    = string
  default = "t3.large"
}

variable "cluster_dashboard_instance_type" {
  type    = string
  default = "t3.medium"
}

# Ubuntu 24.04 LTS — the only release the 5.0 installation assistant's own
# OS-support check accepts without complaint.
data "aws_ami" "cluster_ubuntu_2404" {
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

# The whole cluster shares one security group, which also lets the intra-
# cluster rules be written as self-references rather than a CIDR — closer to
# how a real deployment is scoped, and it keeps 9200/9300 off the internet.
resource "aws_security_group" "indexer_cluster" {
  name        = "wazuh-indexer-cluster-${var.wazuh_version}"
  description = "Wazuh 5.0 indexer cluster documentation test"
  vpc_id      = data.aws_vpc.default.id

  # --- from the operator -------------------------------------------------
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  ingress {
    description = "Wazuh dashboard"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_api_cidrs
  }

  ingress {
    description = "Wazuh manager API"
    from_port   = 55000
    to_port     = 55000
    protocol    = "tcp"
    cidr_blocks = var.allowed_api_cidrs
  }

  ingress {
    description = "Wazuh indexer REST API"
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = var.allowed_api_cidrs
  }

  # --- intra-cluster ------------------------------------------------------
  # Self-referencing: any member of this group may talk to any other on any
  # port. Covers 9200/9300 (indexer REST + transport), 1514/1515/1517 (agent
  # comms, enrolment, and the manager cluster port that a previous pass found
  # missing from the SG and spent real time misdiagnosing as a cert fault),
  # and 55000.
  ingress {
    description = "All intra-cluster traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "wazuh-indexer-cluster-${var.wazuh_version}"
    Purpose = "Wazuh indexer cluster doc test"
  }

  # A security group name is unique per VPC, so a rename must build the
  # replacement before dropping the old one or the instances referencing it
  # block the destroy.
  lifecycle {
    create_before_destroy = true
  }
}

# TTL-only user_data. Kept in a local so every host in this file gets byte-
# identical bootstrap: user_data is part of the instance's replace-triggering
# state, so any per-host variation here would make an unrelated edit churn
# hosts that did not need to change.
locals {
  cluster_user_data = base64encode(local.ttl_prologue)

  cluster_common_tags = {
    Purpose         = "Wazuh indexer cluster doc test"
    TTL_Minutes     = var.resource_ttl_minutes
    AutoTermination = var.enable_auto_termination
  }
}

resource "aws_instance" "indexer" {
  count = var.cluster_indexer_count

  ami                         = data.aws_ami.cluster_ubuntu_2404.id
  instance_type               = var.cluster_indexer_instance_type
  key_name                    = aws_key_pair.cluster.key_name
  subnet_id                   = data.aws_subnet.default.id
  vpc_security_group_ids      = [aws_security_group.indexer_cluster.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  instance_initiated_shutdown_behavior = local.shutdown_behavior
  user_data                            = local.cluster_user_data

  tags = merge(local.cluster_common_tags, {
    Name = "wazuh-indexer-${count.index + 1}-${var.wazuh_version}"
    Role = "indexer"
  })
}

resource "aws_instance" "cluster_manager" {
  ami                         = data.aws_ami.cluster_ubuntu_2404.id
  instance_type               = var.cluster_manager_instance_type
  key_name                    = aws_key_pair.cluster.key_name
  subnet_id                   = data.aws_subnet.default.id
  vpc_security_group_ids      = [aws_security_group.indexer_cluster.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  instance_initiated_shutdown_behavior = local.shutdown_behavior
  user_data                            = local.cluster_user_data

  tags = merge(local.cluster_common_tags, {
    Name = "wazuh-cluster-manager-${var.wazuh_version}"
    Role = "manager"
  })
}

resource "aws_instance" "cluster_dashboard" {
  ami                         = data.aws_ami.cluster_ubuntu_2404.id
  instance_type               = var.cluster_dashboard_instance_type
  key_name                    = aws_key_pair.cluster.key_name
  subnet_id                   = data.aws_subnet.default.id
  vpc_security_group_ids      = [aws_security_group.indexer_cluster.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  instance_initiated_shutdown_behavior = local.shutdown_behavior
  user_data                            = local.cluster_user_data

  tags = merge(local.cluster_common_tags, {
    Name = "wazuh-cluster-dashboard-${var.wazuh_version}"
    Role = "dashboard"
  })
}

# The all-in-one upscale path is a separate scenario in the document and must
# not share hosts with the distributed cluster above.
resource "aws_instance" "allinone" {
  count = var.cluster_create_allinone ? 2 : 0

  ami                         = data.aws_ami.cluster_ubuntu_2404.id
  instance_type               = var.cluster_indexer_instance_type
  key_name                    = aws_key_pair.cluster.key_name
  subnet_id                   = data.aws_subnet.default.id
  vpc_security_group_ids      = [aws_security_group.indexer_cluster.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  instance_initiated_shutdown_behavior = local.shutdown_behavior
  user_data                            = local.cluster_user_data

  tags = merge(local.cluster_common_tags, {
    Name = "wazuh-allinone-${count.index + 1}-${var.wazuh_version}"
    Role = "allinone"
  })
}

# --- outputs ---------------------------------------------------------------
# Private IPs matter as much as public here: opensearch.yml's node identity,
# seed_hosts and the certificate SANs are all written against the private
# address, while SSH and the dashboard are reached over the public one.

output "cluster_indexers" {
  description = "Indexer nodes: name, public and private IP."
  value = [
    for i, n in aws_instance.indexer : {
      name       = "indexer-${i + 1}"
      public_ip  = n.public_ip
      private_ip = n.private_ip
      public_dns = n.public_dns
    }
  ]
}

output "cluster_manager" {
  value = {
    public_ip  = aws_instance.cluster_manager.public_ip
    private_ip = aws_instance.cluster_manager.private_ip
    public_dns = aws_instance.cluster_manager.public_dns
  }
}

output "cluster_dashboard" {
  value = {
    public_ip  = aws_instance.cluster_dashboard.public_ip
    private_ip = aws_instance.cluster_dashboard.private_ip
    url        = "https://${aws_instance.cluster_dashboard.public_ip}"
  }
}

output "cluster_allinone" {
  value = [
    for i, n in aws_instance.allinone : {
      name       = "allinone-${i + 1}"
      public_ip  = n.public_ip
      private_ip = n.private_ip
    }
  ]
}

output "cluster_ssh_commands" {
  description = "Ready-to-paste SSH commands for every host in this test."
  value = concat(
    [for i, n in aws_instance.indexer : "ssh -i ${local_file.cluster_private_key.filename} -o StrictHostKeyChecking=no ubuntu@${n.public_ip}  # indexer-${i + 1}"],
    ["ssh -i ${local_file.cluster_private_key.filename} -o StrictHostKeyChecking=no ubuntu@${aws_instance.cluster_manager.public_ip}  # manager"],
    ["ssh -i ${local_file.cluster_private_key.filename} -o StrictHostKeyChecking=no ubuntu@${aws_instance.cluster_dashboard.public_ip}  # dashboard"],
    [for i, n in aws_instance.allinone : "ssh -i ${local_file.cluster_private_key.filename} -o StrictHostKeyChecking=no ubuntu@${n.public_ip}  # allinone-${i + 1}"]
  )
}
