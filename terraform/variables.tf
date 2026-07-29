variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile to authenticate with (from ~/.aws/credentials)"
  type        = string
  default     = "wazuh"
}

variable "ssh_key_output_path" {
  description = "Path where SSH key will be saved"
  type        = string
  default     = "."
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_api_cidrs" {
  description = "CIDR blocks allowed for Wazuh API access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "wazuh_server_instance_type" {
  description = "Instance type for Wazuh server"
  type        = string
  default     = "t3.xlarge"
}

variable "wazuh_server_volume_size" {
  description = "Root volume size for Wazuh server (GB)"
  type        = number
  default     = 30
}

variable "agent_instance_type" {
  description = "Instance type for the Ubuntu endpoint (Wazuh agent + TheHive, colocated). t3.xlarge = 4 vCPU / 16GB RAM per the infrastructure guide."
  type        = string
  default     = "t3.xlarge"
}

variable "agent_volume_size" {
  description = "Root volume size for the agent+TheHive endpoint (GB). 50GB per the infrastructure guide."
  type        = number
  default     = 50
}

variable "wazuh_version" {
  description = "Wazuh version to install"
  type        = string
  default     = "4.14.6"
}

variable "resource_ttl_minutes" {
  description = "Time-to-live for resources in minutes. Resources auto-terminate after this time."
  type        = number
  default     = 240  # 4 hour default

  validation {
    condition     = var.resource_ttl_minutes > 0 && var.resource_ttl_minutes <= 1440
    error_message = "TTL must be between 1 and 1440 minutes (1 day max)."
  }
}

variable "enable_auto_termination" {
  description = "Enable automatic resource termination after TTL expires"
  type        = bool
  default     = true
}

variable "wazuh_major_version" {
  description = "Major Wazuh version to deploy (4 or 5)"
  type        = number
  default     = 4

  validation {
    condition     = contains([4, 5], var.wazuh_major_version)
    error_message = "Wazuh major version must be 4 or 5."
  }
}

variable "test_scenario" {
  description = "Test scenario to run (controls which resources are deployed)"
  type        = string
  default     = "fresh_deployment"

  validation {
    condition = contains([
      "fresh_deployment",
      "eol_detection",
      "documentation_test",
      "thehive_integration",
      "upgrade_4_to_5",
      "agent_enrollment",
      "dashboard_access"
    ], var.test_scenario)
    error_message = "Invalid test scenario. Must be one of: fresh_deployment, eol_detection, documentation_test, thehive_integration, upgrade_4_to_5, agent_enrollment, dashboard_access."
  }
}
