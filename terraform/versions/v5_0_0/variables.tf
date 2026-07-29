# Wazuh 5.0.0 specific variables (STUB - to be populated after research)

variable "wazuh_version" {
  description = "Wazuh version (5.0.0)"
  type        = string
  default     = "5.0.0"
}

variable "wazuh_install_branch" {
  description = "Wazuh install script branch (MAJOR.MINOR) - TBD for 5.0"
  type        = string
  default     = "5.0"  # RESEARCH: Is this format correct?
}

# v5.0.0 specific settings (to be documented after testing)
variable "wazuh_indexer_listen_port" {
  description = "Port Indexer listens on (check if localhost binding exists in 5.0)"
  type        = number
  default     = 9200
}
