# 00-modules/01-k8s-cluster/variables.tf

# Core cluster configuration
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "Cluster endpoint (VIP or first control plane IP)"
  type        = string
  default     = null
}

variable "talos_version" {
  description = "Talos version to use"
  type        = string
  default     = "v1.10.4"
}

variable "bootstrap_enabled" {
  description = "Whether Terraform should run talosctl bootstrap"
  type        = bool
  default     = true
}

variable "talos_control_plane_patches" {
  description = "Additional YAML patches to apply to control plane machine configuration"
  type        = list(string)
  default     = []
}

variable "talos_worker_patches" {
  description = "Additional YAML patches to apply to worker machine configuration"
  type        = list(string)
  default     = []
}

# Deprecated: Use `kubeprism` variable instead
# # VIP Configuration
# variable "vip" {
#   description = "Virtual IP configuration for control plane HA"
#   type = object({
#     enabled = bool
#     ip      = string
#   })
#   default = {
#     enabled = false
#     ip      = ""
#   }
# }

variable "kubeprism" {
  description = "KubePrism configuration"
  type = object({
    enabled = bool
    port    = number
  })
  default = {
    enabled = true
    port    = 7445
  }
}

# Network Configuration
variable "network" {
  description = "Network configuration for all nodes"
  type = object({
    bridge      = string
    subnet_mask = number
    gateway     = string
    nameservers = list(string)
    vlan_tag    = optional(number)
    mtu         = optional(number, 1500)
    firewall    = optional(bool, false)
    queues      = optional(number, 1)
    rate        = optional(number)
  })
}

# Node Definitions
variable "control_planes" {
  description = "Control plane nodes configuration"
  type = map(object({
    vm_id        = number
    proxmox_node = string
    ip_address   = string
    cpu_cores    = optional(number, 2)
    memory       = optional(number, 2048)
    disk_size    = optional(string, "20G")
    manage_pci   = optional(bool, false)
    ipconfigs    = optional(map(string), {})
    disks = optional(map(object({
      type     = string
      slot     = string
      storage  = string
      size     = string
      format   = optional(string, "qcow2")
      cache    = optional(string, "writethrough")
      iothread = optional(bool, false)
      backup   = optional(bool, true)
    })), {})
    pci_devices = optional(list(object({
      id            = optional(number)
      mapping_id    = optional(string)
      raw_id        = optional(string)
      pcie          = optional(bool, false)
      primary_gpu   = optional(bool, false)
      rombar        = optional(bool, true)
      mdev          = optional(string)
      device_id     = optional(string)
      vendor_id     = optional(string)
      sub_device_id = optional(string)
      sub_vendor_id = optional(string)
    })), [])
  }))

  validation {
    condition     = length(var.control_planes) > 0
    error_message = "Provide at least one control plane node."
  }
}

variable "workers" {
  description = "Worker nodes configuration"
  type = map(object({
    vm_id        = number
    proxmox_node = string
    ip_address   = string
    cpu_cores    = optional(number, 2)
    memory       = optional(number, 2048)
    disk_size    = optional(string, "20G")
    node_type    = optional(string, "worker")
    manage_pci   = optional(bool, false)
    ipconfigs    = optional(map(string), {})
    disks = optional(map(object({
      type     = string
      slot     = string
      storage  = string
      size     = string
      format   = optional(string, "qcow2")
      cache    = optional(string, "writethrough")
      iothread = optional(bool, false)
      backup   = optional(bool, true)
    })), {})
    labels = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    pci_devices = optional(list(object({
      id            = optional(number)
      mapping_id    = optional(string)
      raw_id        = optional(string)
      pcie          = optional(bool, false)
      primary_gpu   = optional(bool, false)
      rombar        = optional(bool, true)
      mdev          = optional(string)
      device_id     = optional(string)
      vendor_id     = optional(string)
      sub_device_id = optional(string)
      sub_vendor_id = optional(string)
    })), [])
  }))
  default = {}
}

# VM Template and Infrastructure
variable "vm_template" {
  description = "Proxmox VM template configuration"
  type = object({
    name       = string
    pool       = optional(string)
    full_clone = optional(bool, true)
  })
}

variable "storage" {
  description = "Storage configuration"
  type = object({
    name = string
  })
}

# Kubernetes Configuration
variable "kubernetes" {
  description = "Kubernetes cluster configuration"
  type = object({
    cni_plugin          = optional(string, "cilium")
    pod_subnets         = optional(list(string), ["10.244.0.0/16"])
    service_subnets     = optional(list(string), ["10.96.0.0/12"])
    kube_proxy_disabled = optional(bool, false)
    kubelet_extra_args  = optional(map(string), {})
  })
  default = {}
}

# Common VM Settings
variable "vm_defaults" {
  description = "Default VM configuration"
  type = object({
    cpu_type        = optional(string, "host")
    bios            = optional(string, "ovmf")
    os_type         = optional(string, "cloud-init")
    qemu_os         = optional(string, "l26")
    boot_order      = optional(string, "order=scsi0")
    boot_disk       = optional(string, "scsi0")
    scsi_controller = optional(string, "virtio-scsi-single")
    numa_enabled    = optional(bool, false)
    hotplug         = optional(string, "network,disk,usb")
    onboot_startup  = optional(bool, true)
    startup         = optional(string, "")
    protection      = optional(bool, false)
    force_create    = optional(bool, false)
  })
  default = {}
}

variable "cloud_init" {
  description = "Cloud-init configuration"
  type = object({
    enabled      = optional(bool, true)
    user         = optional(string, "talos")
    password     = optional(string)
    ssh_keys     = optional(string)
    nameserver   = optional(string, "1.1.1.1")
    searchdomain = optional(string, "local")
  })
  default = {}
}

variable "common_tags" {
  description = "Common tags for all VMs"
  type        = list(string)
  default     = ["terraform", "talos"]
}
