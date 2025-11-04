locals {
  default_network = {
    bridge      = "vmbr0"
    subnet_mask = 24
    gateway     = "192.0.2.1"
    nameservers = ["192.0.2.53"]
  }

  default_control_planes = {
    cp1 = {
      vm_id        = 501
      proxmox_node = "pve-1"
      ip_address   = "192.0.2.11"
      cpu_cores    = 4
      memory       = 4096
    }
  }

  default_workers = {
    worker1 = {
      vm_id        = 601
      proxmox_node = "pve-1"
      ip_address   = "192.0.2.21"
      cpu_cores    = 4
      memory       = 8192
      labels = {
        "workload-type" = "general"
      }
    }
  }

  default_vm_template = {
    name       = "talos-template"
    full_clone = true
  }

  default_storage = {
    name = "local-lvm"
  }

  default_kubernetes = {
    cni_plugin      = "none"
    pod_subnets     = ["10.244.0.0/16"]
    service_subnets = ["10.96.0.0/12"]
  }

  default_vm_defaults = {
    cpu_type        = "host"
    bios            = "ovmf"
    os_type         = "cloud-init"
    qemu_os         = "l26"
    hotplug         = "disk,network,usb"
    scsi_controller = "virtio-scsi-single"
    onboot_startup  = true
    boot_order      = "order=scsi0;ide2;net0"
    boot_disk       = "scsi0"
  }

  default_cloud_init = {
    user         = "talos"
    nameserver   = "192.0.2.53"
    searchdomain = "example.local"
  }

  default_common_tags = ["terraform", "talos", "example"]
}

module "homelab_example" {
  source = "../../modules/talos-k8s-cluster"

  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  talos_version     = var.talos_version
  bootstrap_enabled = var.bootstrap_enabled

  network        = local.default_network
  control_planes = local.default_control_planes
  workers        = local.default_workers

  vm_template = local.default_vm_template
  storage     = local.default_storage

  kubernetes  = local.default_kubernetes
  vm_defaults = local.default_vm_defaults
  cloud_init  = local.default_cloud_init
  common_tags = local.default_common_tags
}
