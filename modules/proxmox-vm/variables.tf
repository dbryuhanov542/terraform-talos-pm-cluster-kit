# # Proxmox Provider Variables
# variable "pm_api_url" {
#   description = "Proxmox API URL (e.g. 'https://pve.example.com:8006/api2/json')"
#   type        = string
#   sensitive   = true
# }

# variable "pm_api_token_id" {
#   description = "Proxmox API token ID (e.g. 'terraform@pve!terraform-token')"
#   type        = string
#   sensitive   = true
# }

# variable "pm_api_token_secret" {
#   description = "Proxmox API token secret"
#   type        = string
#   sensitive   = true
# }

# variable "pm_tls_insecure" {
#   description = "Skip TLS verification (true/false)"
#   type        = bool
#   default     = true
# }

# Output-related variables
variable "output_ip_wait" {
  description = "Wait for VM IP address in outputs"
  type        = bool
  default     = true
}

# Basic VM Settings
variable "name" {
  description = "VM name as displayed in Proxmox UI"
  type        = string
  default     = "terraform-vm"
}

variable "vm_id" {
  description = "Unique numeric identifier for the VM (100-999999999)"
  type        = number
  default     = null # Proxmox will auto-assign if null
}

variable "desc" {
  description = "Description/notes for the VM"
  type        = string
  default     = "Created by Terraform"
}

variable "node" {
  description = "Proxmox node where VM will be created"
  type        = string
  default     = "pve"
}

variable "tags" {
  description = "Tags for VM organization (comma-separated)"
  type        = string
  default     = ""
}

# Template and Cloning
variable "clone_template" {
  description = "Template name to clone from"
  type        = string
  default     = "ubuntu-2204-cloudinit"
}

variable "full_clone" {
  description = "Create full clone (true) or linked clone (false)"
  type        = bool
  default     = true
}

variable "pool" {
  description = "Resource pool for the VM"
  type        = string
  default     = ""
}

variable "qemu_os" {
  description = "OS type for QEMU optimization (deprecated)"
  type        = string
  default     = "l26" # Linux 2.6+ kernel
}

# System Configuration
variable "agent" {
  description = "Enable QEMU guest agent (true/false)"
  type        = bool
  default     = true
}

variable "bios" {
  description = "BIOS type: seabios or ovmf (UEFI)"
  type        = string
  default     = "seabios"
}

variable "os_type" {
  description = "OS type for QEMU optimization (deprecated)"
  type        = string
  default     = "cloud-init"
}

variable "machine" {
  description = "Machine type (pc, q35, etc.)"
  type        = string
  default     = null
}

variable "kvm" {
  description = "Enable KVM hardware virtualization"
  type        = bool
  default     = true
}

# VM Lifecycle
variable "onboot_startup" {
  description = "Auto-start VM when host boots"
  type        = bool
  default     = false
}

variable "startup" {
  description = "Startup/shutdown order (e.g. 'order=1,up=60,down=60')"
  type        = string
  default     = ""
}

variable "protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

# Boot Configuration
variable "boot" {
  description = "Boot order (e.g. 'order=scsi0;ide2;net0')"
  type        = string
  default     = "order=scsi0"
}

variable "bootdisk" {
  description = "Default boot disk (e.g. 'scsi0')"
  type        = string
  default     = "scsi0"
}

variable "pxe" {
  description = "Enable PXE boot"
  type        = bool
  default     = false

  validation {
    condition     = !(var.pxe && var.clone_template != null)
    error_message = "Нельзя одновременно использовать PXE и clone_template."
  }
}

# CPU Configuration
variable "cpu_sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1
}

variable "cpu_cores" {
  description = "Number of cores per socket"
  type        = number
  default     = 2
}

variable "cpu_type" {
  description = "CPU type (kvm64, host, Haswell, etc.)"
  type        = string
  default     = "host"
}

variable "numa_enabled" {
  description = "Enable NUMA topology"
  type        = bool
  default     = false
}

# Memory Configuration
variable "memory" {
  description = "RAM amount in MB"
  type        = number
  default     = 2048
}

variable "balloon" {
  description = "Minimum guaranteed RAM in MB (0 = ballooning disabled)"
  type        = number
  default     = 0
}

# Hardware Features
variable "hotplug" {
  description = "Hotplug capabilities (disk,network,usb,memory,cpu)"
  type        = string
  default     = "network,disk,usb"
}

variable "scsi_controller" {
  description = "SCSI controller type (virtio-scsi-pci, lsi, etc.)"
  type        = string
  default     = "virtio-scsi-single"
}

# Network Configuration
variable "networks" {
  description = "Network interfaces configuration"
  type = map(object({
    bridge   = string
    model    = optional(string)
    firewall = optional(bool)
    vlan_tag = optional(number)
    mtu      = optional(number)
    queues   = optional(number)
    rate     = optional(number)
    macaddr  = optional(string)
  }))
  default = {
    net0 = {
      bridge = "vmbr0"
      model  = "virtio"
    }
  }
}

# Disk Configuration
variable "disks" {
  description = "List of disks to attach to the VM"
  type = list(object({
    type        = string                   # "scsi", "virtio", "ide"
    slot        = string                   # 0, 1, 2, etc.
    storage     = optional(string)         # Storage name
    size        = optional(string)         # Disk size (e.g., "20G")
    format      = optional(string, "raw")  # Disk format: "raw", "qcow2", "vmdk"
    cache       = optional(string, "none") # Cache mode
    backup      = optional(bool, true)     # Include in backups
    iothread    = optional(bool, false)    # Enable IO threads
    discard     = optional(bool, false)    # Enable discard/TRIM
    replicate   = optional(bool, true)     # Enable replication
    emulatessd  = optional(bool, false)    # Emulate SSD
    passthrough = optional(bool, false)    # Enable passthrough
    disk_file   = optional(string)         # File path for passthrough
  }))
  default = []

  validation {
    condition = alltrue([
      for disk in var.disks :
      contains(["disk", "cloudinit", "passthrough"], disk.type)
    ])
    error_message = "Disk type must be one of: disk, cloudinit, passthrough."
  }

  validation {
    condition = alltrue([
      for disk in var.disks :
      disk.type != "disk" || disk.storage != null
    ])
    error_message = "Storage must be specified for disk type."
  }

  validation {
    condition = alltrue([
      for disk in var.disks :
      disk.type != "cloudinit" || disk.storage != null
    ])
    error_message = "Storage must be specified for cloudinit type."
  }

  validation {
    condition = alltrue([
      for disk in var.disks :
      disk.type != "passthrough" || disk.disk_file != null
    ])
    error_message = "File path must be specified for passthrough type."
  }
}

variable "pci_devices" {
  description = "List of PCI devices to passthrough to the VM"
  type = list(object({
    id            = optional(number)      # PCI slot ID (0-15), defaults to list index
    mapping_id    = optional(string)      # Mapping ID for resource mapping (conflicts with raw_id)
    raw_id        = optional(string)      # Raw PCI device ID (e.g., "0000:01:00.0", conflicts with mapping_id)
    pcie          = optional(bool, false) # Enable PCIe passthrough
    primary_gpu   = optional(bool, false) # Set as primary GPU
    rombar        = optional(bool, true)  # Enable ROM BAR
    mdev          = optional(string)      # Mediated device type
    device_id     = optional(string)      # Device ID of the PCI device
    vendor_id     = optional(string)      # Vendor ID of the PCI device
    sub_device_id = optional(string)      # Sub-device ID of the PCI device
    sub_vendor_id = optional(string)      # Sub-vendor ID of the PCI device
  }))
  default = []

  validation {
    condition = alltrue([
      for pci in var.pci_devices :
      (pci.mapping_id != null) != (pci.raw_id != null)
    ])
    error_message = "Each PCI device must have either 'mapping_id' or 'raw_id', but not both."
  }

  validation {
    condition = alltrue([
      for pci in var.pci_devices :
      pci.id == null || (pci.id >= 0 && pci.id <= 15)
    ])
    error_message = "PCI device id must be between 0 and 15."
  }
}

variable "manage_pci" {
  description = "Whether Terraform should manage PCI passthrough settings (set to true only when the Proxmox provider supports it in your environment)"
  type        = bool
  default     = false
}

# Cloud-Init Configuration
variable "ci_user" {
  description = "Cloud-init user name"
  type        = string
  default     = "ubuntu"
}

variable "ci_password" {
  description = "Cloud-init password (plaintext)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_keys" {
  description = "SSH public keys for cloud-init (newline-separated)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "nameserver" {
  description = "DNS server for cloud-init"
  type        = string
  default     = "8.8.8.8"
}

variable "searchdomain" {
  description = "DNS search domain for cloud-init"
  type        = string
  default     = ""
}

variable "ipconfigs" {
  description = "Map of IP configurations (ipconfig0-15)"
  type        = map(string)
  default = {
    ipconfig0 = "ip=dhcp"
  }

  validation {
    condition = alltrue([
      for key in keys(var.ipconfigs) :
      can(regex("^ipconfig([0-9]|1[0-5])$", key))
    ])
    error_message = "Keys must be in format ipconfig0 through ipconfig15."
  }
}

variable "cicustom" {
  description = "Custom cloud-init files (e.g. 'user=local:snippets/userconfig.yml')"
  type        = string
  default     = ""
}

# EFI Configuration
variable "efi_enabled" {
  description = "Enable EFI disk"
  type        = bool
  default     = false
}

variable "efi_storage" {
  description = "Storage for EFI disk"
  type        = string
  default     = "local-lvm"
}


variable "efi_pre_enrolled_keys" {
  description = "Use pre-enrolled secure boot keys"
  type        = bool
  default     = false
}

# Advanced
variable "force_create" {
  description = "Force VM creation (overwrite existing)"
  type        = bool
  default     = false
}

# DNS Integration
variable "dns" {
  description = "Optional DNS configuration block for automatic A-record creation"
  type = object({
    zone     = string                # DNS zone (e.g., 'lvstrk.local.')
    hostname = optional(string)      # Hostname (defaults to VM name if not provided)
    ip       = optional(string)      # IP address (auto-extracted from ipconfig0 if not provided)
    ttl      = optional(number, 300) # TTL for the record
  })
  default = null
}
