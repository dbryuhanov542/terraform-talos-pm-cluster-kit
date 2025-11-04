# 00-modules/00-proxmox-vm/main.tf

resource "proxmox_vm_qemu" "vm" {
  # *VM Identification and Basic Settings*
  name        = var.name  # VM name as displayed in Proxmox UI
  vmid        = var.vm_id # Unique numeric identifier for the VM (100-999999999)
  description = var.desc  # Description/notes for the VM
  target_node = var.node  # Proxmox node where VM will be created
  tags        = var.tags  # Tags for VM organization (comma-separated)

  # *Template and Cloning Configuration*
  clone      = var.clone_template # Template name to clone from
  full_clone = var.full_clone     # true = full clone, false = linked clone
  pool       = var.pool           # Resource pool for the VM
  qemu_os    = var.qemu_os

  # *QEMU Agent and System Configuration*
  agent   = var.agent ? 1 : 0 # Enable/disable QEMU guest agent (0/1)
  bios    = var.bios          # BIOS type: "seabios" or "ovmf" (UEFI)
  os_type = var.os_type       # OS type for QEMU optimization (deprecated, use 'vmgenid')
  kvm     = var.kvm           # Enable KVM virtualization (default: true)
  machine = var.machine       # Machine type (pc, q35, etc.)

  # *VM Lifecycle and Startup Configuration*
  onboot     = var.onboot_startup # Auto-start VM when Proxmox node boots
  startup    = var.startup        # Startup/shutdown order and delays
  protection = var.protection     # Enable deletion protection

  # *Boot and Disk Configuration*
  boot     = var.boot     # Boot order (e.g., "order=scsi0;ide2;net0")
  bootdisk = var.bootdisk # Boot disk identifier (e.g., "scsi0", "ide0")

  # *CPU Configuration Block*
  cpu {
    cores   = var.cpu_cores    # Number of cores per socket
    sockets = var.cpu_sockets  # Number of CPU sockets (typically 1)
    type    = var.cpu_type     # CPU type: "kvm64", "host", "Haswell", etc.
    numa    = var.numa_enabled # Enable NUMA topology
  }

  # *Memory Configuration*
  memory  = var.memory  # RAM amount in MB (e.g., 2048 for 2GB)
  balloon = var.balloon # Memory ballooning (0 = disabled, >0 = minimum guaranteed RAM)

  # *Hardware and Virtualization Features*
  hotplug = var.hotplug         # Hotplug capabilities: "disk,network,usb,memory,cpu"
  scsihw  = var.scsi_controller # SCSI controller type: "virtio-scsi-pci", "lsi", etc.   

  # *Network Configuration*
  dynamic "network" {
    for_each = var.networks
    content {
      id       = tonumber(regex("[0-9]+", network.key))
      bridge   = network.value.bridge              # Network bridge (e.g., "vmbr0")
      model    = try(network.value.model, null)    # Network interface model
      firewall = try(network.value.firewall, null) # Enable firewall
      tag      = try(network.value.vlan_tag, null) # VLAN tag
      mtu      = try(network.value.mtu, null)      # MTU size
      queues   = try(network.value.queues, null)   # Number of queues
      rate     = try(network.value.rate, null)     # Rate limit (MB/s)
      macaddr  = try(network.value.macaddr, null)  # Custom MAC address
    }
  }

  # *Dynamic Disk Configuration*
  dynamic "disk" {
    for_each = { for idx, disk in var.disks : idx => disk }
    content {
      type       = disk.value.type
      slot       = disk.value.slot
      storage    = try(disk.value.storage, null)
      size       = try(disk.value.size, null)
      format     = try(disk.value.format, "raw")
      cache      = try(disk.value.cache, "none")
      backup     = try(disk.value.backup, true)
      iothread   = try(disk.value.iothread, false)
      discard    = try(disk.value.discard, false)
      replicate  = try(disk.value.replicate, true)
      emulatessd = try(disk.value.emulatessd, false)
      # Passthrough-specific parameters
      passthrough = contains(keys(disk.value), "passthrough") ? disk.value.passthrough : null
      disk_file   = try(disk.value.disk_file, null)
    }
  }

  # *EFI Configuration*
  dynamic "efidisk" {
    for_each = var.efi_enabled ? [1] : []
    content {
      storage           = var.efi_storage           # EFI disk storage
      pre_enrolled_keys = var.efi_pre_enrolled_keys # Pre-enrolled keys
    }
  }

  # *Dynamic PCI Passthrough Configuration*
  dynamic "pci" {
    for_each = var.manage_pci ? { for idx, pci_device in var.pci_devices : idx => pci_device } : {}
    content {
      id            = try(pci.value.id, pci.key)         # PCI slot ID (0-15), defaults to loop key
      mapping_id    = try(pci.value.mapping_id, null)    # Mapping ID for resource mapping (conflicts with raw_id)
      raw_id        = try(pci.value.raw_id, null)        # Raw PCI device ID (e.g., "0000:01:00.0", conflicts with mapping_id)
      pcie          = try(pci.value.pcie, false)         # Enable PCIe passthrough
      primary_gpu   = try(pci.value.primary_gpu, false)  # Set as primary GPU
      rombar        = try(pci.value.rombar, true)        # Enable ROM BAR
      mdev          = try(pci.value.mdev, null)          # Mediated device type
      device_id     = try(pci.value.device_id, null)     # Device ID of the PCI device
      vendor_id     = try(pci.value.vendor_id, null)     # Vendor ID of the PCI device
      sub_device_id = try(pci.value.sub_device_id, null) # Sub-device ID of the PCI device
      sub_vendor_id = try(pci.value.sub_vendor_id, null) # Sub-vendor ID of the PCI device
    }
  }

  # *Cloud-Init Configuration*
  ciuser       = var.os_type == "cloud-init" ? var.ci_user : null
  cipassword   = var.os_type == "cloud-init" ? var.ci_password : null
  sshkeys      = var.os_type == "cloud-init" ? var.ssh_keys : null
  nameserver   = var.os_type == "cloud-init" ? var.nameserver : null
  searchdomain = var.os_type == "cloud-init" ? var.searchdomain : null

  # *Static IP Configuration*
  ipconfig0  = var.os_type == "cloud-init" ? try(var.ipconfigs["ipconfig0"], null) : null
  ipconfig1  = var.os_type == "cloud-init" ? try(var.ipconfigs["ipconfig1"], null) : null
  ipconfig2  = var.os_type == "cloud-init" ? try(var.ipconfigs["ipconfig2"], null) : null
  ipconfig3  = var.os_type == "cloud-init" ? try(var.ipconfigs["ipconfig3"], null) : null
  ipconfig4  = var.os_type == "cloud-init" ? try(var.ipconfigs["ipconfig4"], null) : null
  ipconfig5  = var.os_type == "cloud-init" ? try(var.ipconfigs["ipconfig5"], null) : null
  ipconfig6  = var.os_type == "cloud-init" ? try(var.ipconfigs["ipconfig6"], null) : null
  ipconfig7  = var.os_type == "cloud-init" ? try(var.ipconfigs["ipconfig7"], null) : null
  ipconfig8  = var.os_type == "cloud-init" ? try(var.ipconfigs["ipconfig8"], null) : null
  ipconfig9  = var.os_type == "cloud-init" ? try(var.ipconfigs["ipconfig9"], null) : null
  ipconfig10 = var.os_type == "cloud-init" ? try(var.ipconfigs["ipconfig10"], null) : null
  ipconfig11 = var.os_type == "cloud-init" ? try(var.ipconfigs["ipconfig11"], null) : null
  ipconfig12 = var.os_type == "cloud-init" ? try(var.ipconfigs["ipconfig12"], null) : null
  ipconfig13 = var.os_type == "cloud-init" ? try(var.ipconfigs["ipconfig13"], null) : null
  ipconfig14 = var.os_type == "cloud-init" ? try(var.ipconfigs["ipconfig14"], null) : null
  ipconfig15 = var.os_type == "cloud-init" ? try(var.ipconfigs["ipconfig15"], null) : null

  cicustom = var.os_type == "cloud-init" ? var.cicustom : null

  # *Advanced System Configuration*
  force_create = var.force_create # Force creation

  lifecycle {
    ignore_changes = [
      bootdisk, # Bootdisk may change after initial setup
      disk,     # Disk sizes may be expanded
      tags,     # Tags may be modified manually
      ciuser,
      cipassword,
      sshkeys,
      pci,
    ]
  }
}

# *Local Values for DNS Configuration*
locals {
  # Check if DNS block is provided
  dns_enabled = var.dns != null

  # Extract IP from ipconfig0 if not provided in dns block
  # Expected format: "ip=192.168.1.100/24,gw=192.168.1.1" or "ip=dhcp"
  ipconfig0_value = try(var.ipconfigs["ipconfig0"], "ip=dhcp")
  extracted_ip = local.dns_enabled ? (
    var.dns.ip != null ? var.dns.ip : (
      can(regex("ip=([0-9.]+)", local.ipconfig0_value)) ?
      regex("ip=([0-9.]+)", local.ipconfig0_value)[0] :
      null
    )
  ) : null

  # Use provided hostname or default to VM name
  dns_hostname = local.dns_enabled ? (
    var.dns.hostname != null ? var.dns.hostname : var.name
  ) : null

  # Check if DNS creation is possible
  dns_ready = local.dns_enabled && local.extracted_ip != null
}

# *DNS A-Record Creation*
resource "dns_a_record_set" "vm_dns" {
  count = local.dns_ready ? 1 : 0

  zone = var.dns.zone
  name = local.dns_hostname
  addresses = [
    local.extracted_ip
  ]
  ttl = var.dns.ttl

  depends_on = [proxmox_vm_qemu.vm]
}
