variable "pm_api_url" {
  description = "Proxmox API URL (e.g. https://pve.example.com:8006/api2/json)"
  type        = string
  sensitive   = true
}

variable "pm_api_token_id" {
  description = "Proxmox API token ID (e.g. terraform@pve!token)"
  type        = string
  sensitive   = true
}

variable "pm_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "pm_tls_insecure" {
  description = "Skip TLS verification when talking to the Proxmox API"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Logical cluster name (used for VM names and Talos context)"
  type        = string
  default     = "homelab-example"
}

variable "cluster_endpoint" {
  description = "Kubernetes API endpoint (defaults to the first control-plane IP)"
  type        = string
  default     = null
}

variable "talos_version" {
  description = "Talos release used for secrets and machine configuration"
  type        = string
  default     = "v1.10.4"
}

variable "bootstrap_enabled" {
  description = "Whether Terraform should run the Talos bootstrap step"
  type        = bool
  default     = true
}
