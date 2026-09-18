# ---------------------------------------------------------------------------
# Isolated terraform root for the Wazuh 5.0 "Wazuh indexer cluster" doc test.
#
# Separate from ../main.tf on purpose. The baseline root builds a single
# all-in-one server plus one agent and its outputs reference those two
# instances directly, so neutralising them with count = 0 in an override would
# break every one of those outputs. Its own root means this test can be
# planned, applied and destroyed on its own state with no -target juggling and
# no risk to a concurrent test using the baseline.
#
# Topology lives in topology.tf. This file is provider, network and SSH key.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

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
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# --- network ---------------------------------------------------------------
# Default VPC, and a single AZ for every host. One AZ is deliberate: the
# indexer's transport layer chats constantly between nodes, so keeping them in
# one AZ avoids cross-AZ data charges and removes inter-AZ latency as a
# variable when judging whether a documented cluster-health outcome reproduces.

data "aws_vpc" "default" {
  default = true
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_subnet" "default" {
  availability_zone = data.aws_availability_zones.available.names[0]
  vpc_id            = data.aws_vpc.default.id
  default_for_az    = true
}

# --- SSH key ---------------------------------------------------------------
# Its own key, named distinctly from the baseline root's "wazuh-test-key-*":
# an EC2 key pair name is unique per account+region, so sharing one name with
# a concurrent test in this shared account is a collision waiting to happen.

resource "tls_private_key" "cluster" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "cluster" {
  key_name   = "wazuh-idxcluster-key-${var.wazuh_version}"
  public_key = tls_private_key.cluster.public_key_openssh

  tags = {
    Name = "wazuh-idxcluster-key-${var.wazuh_version}"
  }
}

resource "local_file" "cluster_private_key" {
  content         = tls_private_key.cluster.private_key_pem
  filename        = "${path.module}/wazuh-idxcluster-key.pem"
  file_permission = "0600"

  # OpenSSH on Windows refuses a key any account other than the owner can
  # read, and file_permission alone does not produce that ACL on NTFS — the
  # inherited ACEs have to be stripped explicitly or every ssh in this test
  # fails with UNPROTECTED PRIVATE KEY FILE.
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $p = "${abspath(path.module)}\wazuh-idxcluster-key.pem"
      icacls $p /inheritance:r | Out-Null
      icacls $p /grant:r "$($env:USERNAME):(R)" | Out-Null
    EOT
  }
}

# --- TTL -------------------------------------------------------------------
# Enforced, not declared: each host runs `shutdown -h +N` as the very first
# action in user_data, paired with instance_initiated_shutdown_behavior =
# "terminate" so the EBS volumes go away too.
#
# Set this once, high, and leave it alone. The value is baked into user_data,
# so editing it later replaces EVERY instance in this root, not just the one
# you meant to extend.

locals {
  # A heredoc cannot be embedded directly in a ternary, so both branches are
  # built separately and the ternary only selects between two plain values.
  ttl_prologue_enabled = <<-EOT
    #!/bin/bash
    # --- TTL self-termination (${var.resource_ttl_minutes} min) ---
    /sbin/shutdown -h +${var.resource_ttl_minutes} "Auto-terminating after ${var.resource_ttl_minutes}min TTL" || true
    echo "TTL_SCHEDULED=$(date -Is) MINUTES=${var.resource_ttl_minutes}" > /root/TTL_SCHEDULED
    # --- end TTL ---
  EOT

  ttl_prologue_disabled = <<-EOT
    #!/bin/bash
    # TTL enforcement disabled (enable_auto_termination = false)
  EOT

  ttl_prologue = var.enable_auto_termination ? local.ttl_prologue_enabled : local.ttl_prologue_disabled

  shutdown_behavior = var.enable_auto_termination ? "terminate" : "stop"
}

output "ttl_configuration" {
  value = {
    enabled           = var.enable_auto_termination
    minutes           = var.resource_ttl_minutes
    hours             = var.resource_ttl_minutes / 60
    shutdown_behavior = local.shutdown_behavior
    verify_on_host    = "cat /root/TTL_SCHEDULED && shutdown --show 2>/dev/null || sudo shutdown --show"
  }
}

output "private_key_path" {
  value = local_file.cluster_private_key.filename
}
