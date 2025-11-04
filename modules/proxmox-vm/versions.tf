# Module Version Requirements
# This file defines the minimum required versions for the module

terraform {
  required_version = ">= 1.8.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc03"
    }

    dns = {
      source  = "hashicorp/dns"
      version = "~> 3.4"
    }
  }
}
