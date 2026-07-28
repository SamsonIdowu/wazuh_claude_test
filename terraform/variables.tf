variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
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
  description = "Instance type for Wazuh agent"
  type        = string
  default     = "t3.medium"
}

variable "agent_volume_size" {
  description = "Root volume size for agent (GB)"
  type        = number
  default     = 20
}

variable "wazuh_version" {
  description = "Wazuh version to install"
  type        = string
  default     = "4.14.6"
}

variable "resource_ttl_minutes" {
  description = "Time-to-live for resources in minutes. Resources auto-terminate after this time."
  type        = number
  default     = 60  # 1 hour default

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

variable "thehive_instance_type" {
  description = "Instance type for TheHive server"
  type        = string
  default     = "t3.medium"
}

variable "thehive_volume_size" {
  description = "Root volume size for TheHive server (GB)"
  type        = number
  default     = 20
}
