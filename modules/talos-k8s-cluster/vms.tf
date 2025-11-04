# 00-modules/01-k8s-cluster/vms.tf

module "cluster_vms" {
  source = "../00-proxmox-vm"

  for_each = local.all_nodes

  # VM Basic Configuration
  name  = each.value.name
  vm_id = each.value.vm_id
  desc  = "Talos Kubernetes ${title(each.value.node_type)} Node"
  node  = each.value.proxmox_node
  tags  = join(",", concat(var.common_tags, ["k8s", each.value.node_type, var.cluster_name]))

  # Template Configuration
  clone_template = var.vm_template.name
  full_clone     = var.vm_template.full_clone
  pool           = var.vm_template.pool
  qemu_os        = var.vm_defaults.qemu_os

  # System Configuration
  agent   = true
  bios    = var.vm_defaults.bios
  os_type = var.vm_defaults.os_type
  kvm     = true

  # Lifecycle Configuration
  onboot_startup = var.vm_defaults.onboot_startup
  startup        = var.vm_defaults.startup
  protection     = var.vm_defaults.protection

  # Boot Configuration
  boot     = var.vm_defaults.boot_order
  bootdisk = var.vm_defaults.boot_disk

  # CPU Configuration
  cpu_cores    = each.value.cpu_cores
  cpu_sockets  = 1
  cpu_type     = var.vm_defaults.cpu_type
  numa_enabled = var.vm_defaults.numa_enabled

  # Memory Configuration
  memory  = each.value.memory
  balloon = 0

  # Hardware Configuration
  hotplug         = var.vm_defaults.hotplug
  scsi_controller = var.vm_defaults.scsi_controller

  # Network Configuration
  networks = {
    net0 = {
      bridge   = var.network.bridge
      model    = "virtio"
      firewall = var.network.firewall
      vlan_tag = var.network.vlan_tag
      mtu      = var.network.mtu
      queues   = var.network.queues
      rate     = var.network.rate
      macaddr  = null
    }
  }

  # Disk Configuration - convert map to list for proxmox-vm module
  disks = concat(
    [
      for slot, disk in each.value.disks : merge(
        {
          type        = "disk"
          slot        = slot
          storage     = var.storage.name
          size        = try(each.value.disk_size, "50G")
          format      = "qcow2"
          cache       = "writethrough"
          iothread    = false
          backup      = true
          replicate   = true
          discard     = false
          emulatessd  = false
          passthrough = null
          disk_file   = null
        },
        disk,
        {
          slot    = try(disk.slot, slot)
          storage = try(disk.storage, var.storage.name)
          size    = try(disk.size, try(each.value.disk_size, "50G"))
          format  = try(disk.format, "qcow2")
          cache   = try(disk.cache, "writethrough")
        }
      )
    ],
    local.cloud_init_enabled ? [
      {
        type    = "cloudinit"
        slot    = "ide2"
        storage = var.storage.name
      }
    ] : []
  )

  # PCI Devices Configuration
  pci_devices = each.value.pci_devices
  manage_pci  = each.value.manage_pci

  # Cloud-Init Configuration
  ci_user      = local.cloud_init_enabled ? try(var.cloud_init.user, null) : null
  ci_password  = local.cloud_init_enabled ? try(var.cloud_init.password, null) : null
  ssh_keys     = local.cloud_init_enabled ? try(var.cloud_init.ssh_keys, null) : null
  nameserver   = local.cloud_init_enabled ? try(var.cloud_init.nameserver, null) : null
  searchdomain = local.cloud_init_enabled ? try(var.cloud_init.searchdomain, null) : null
  ipconfigs    = each.value.ipconfigs

  # EFI Configuration
  efi_enabled           = true
  efi_storage           = var.storage.name
  efi_pre_enrolled_keys = false

  # Advanced Configuration
  force_create = var.vm_defaults.force_create
}
