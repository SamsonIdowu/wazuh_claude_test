# Wazuh 4.14.6 specific variables

variable "wazuh_version" {
  description = "Wazuh version (4.14.6)"
  type        = string
  default     = "4.14.6"
}

variable "wazuh_install_branch" {
  description = "Wazuh install script branch (MAJOR.MINOR)"
  type        = string
  default     = "4.14"
}

# v4.14.6 specific settings
variable "wazuh_indexer_listen_port" {
  description = "Port Indexer listens on (may be localhost-only in 4.14.6)"
  type        = number
  default     = 9200
}
