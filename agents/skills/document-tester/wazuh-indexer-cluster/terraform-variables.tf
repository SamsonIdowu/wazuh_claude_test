variable "aws_region" {
  description = "AWS region for the cluster test."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Named profile in ~/.aws/credentials. Credentials are never committed here."
  type        = string
  default     = "wazuh"
}

variable "wazuh_version" {
  description = "Version label. Suffixes every account-unique name (key pair, security group) so a concurrent test in this shared AWS account cannot collide with this one."
  type        = string
  default     = "5.0.0"
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs allowed to SSH. 0.0.0.0/0 is convenient for a short test; prefer YOUR.IP/32 for anything longer-lived."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_api_cidrs" {
  description = "CIDRs allowed to reach the dashboard (443), manager API (55000) and indexer REST API (9200)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "resource_ttl_minutes" {
  description = "Minutes before each host self-terminates. Baked into user_data, so changing it replaces every instance in this root — set it once. Account policy caps this at 240 (4h); see the validation below."
  type        = number
  default     = 240

  validation {
    condition     = var.resource_ttl_minutes > 0 && var.resource_ttl_minutes <= 240
    error_message = "TTL must be between 1 and 240 minutes (4h account policy)."
  }
}

variable "enable_auto_termination" {
  description = "Schedule shutdown -h in user_data and terminate (not stop) on shutdown."
  type        = bool
  default     = true
}
