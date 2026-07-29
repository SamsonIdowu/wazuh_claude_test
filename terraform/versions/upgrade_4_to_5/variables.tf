# Variables for upgrade_4_to_5 scenario
#
# This scenario reuses variables from v4_14_6 and passes them through.
# See terraform/versions/v4_14_6/variables.tf for detailed descriptions.

variable "wazuh_version" {
  description = "Wazuh version (4.14.6 for baseline)"
  type        = string
  default     = "4.14.6"
}

variable "instance_type" {
  description = "EC2 instance type for Wazuh server"
  type        = string
  default     = "t3.xlarge"
}

variable "ami_filter" {
  description = "AMI filter for Ubuntu 22.04 LTS"
  type        = string
  default     = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
}

variable "environment" {
  description = "Environment tag (dev/test/prod)"
  type        = string
  default     = "test"
}

variable "wazuh_test_key_pair" {
  description = "AWS EC2 key pair name for SSH access"
  type        = string
  default     = "wazuh-test-key"
}

variable "availability_zone" {
  description = "AWS availability zone"
  type        = string
  default     = "us-east-1a"
}

variable "resource_ttl_minutes" {
  description = "Time-to-live for resources (auto-termination)"
  type        = number
  default     = 120  # 2 hours for upgrade testing
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    "Project"      = "wazuh-testing"
    "TestScenario" = "upgrade_4_to_5"
    "ManagedBy"    = "terraform"
  }
}
