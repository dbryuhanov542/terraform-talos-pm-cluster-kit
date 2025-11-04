# 00-modules/01-k8s-cluster/locals.tf

locals {
  cloud_init_enabled = try(var.cloud_init.enabled, true)

  # Merge all nodes for unified processing
  all_nodes = merge(
    # Control plane nodes
    {
      for name, config in var.control_planes : name => merge(config, {
        name      = "${var.cluster_name}-cp-${name}"
        node_type = "controlplane"
        ipconfigs = length(keys(try(config.ipconfigs, {}))) > 0 ? config.ipconfigs : {
          "ipconfig0" = "ip=${config.ip_address}/${var.network.subnet_mask},gw=${var.network.gateway}"
        }
        ipconfig0 = lookup(
          length(keys(try(config.ipconfigs, {}))) > 0 ? config.ipconfigs : {
            "ipconfig0" = "ip=${config.ip_address}/${var.network.subnet_mask},gw=${var.network.gateway}"
          },
          "ipconfig0",
          null
        )
        labels      = {}
        taints      = []
        manage_pci  = try(config.manage_pci, false)
        pci_devices = try(config.pci_devices, [])
        # Default disk configuration for control planes
        disks = length(keys(config.disks)) > 0 ? config.disks : {
          "scsi0" = {
            type     = "disk"
            slot     = "scsi0"
            storage  = var.storage.name
            size     = try(config.disk_size, "50G")
            format   = "qcow2"
            cache    = "writethrough"
            iothread = false
            backup   = true
          }
        }
      })
    },
    # Worker nodes
    {
      for name, config in var.workers : name => merge(config, {
        name      = "${var.cluster_name}-${try(config.node_type, "worker")}-${name}"
        node_type = try(config.node_type, "worker") # ← ДОБАВЛЕНО!
        ipconfigs = length(keys(try(config.ipconfigs, {}))) > 0 ? config.ipconfigs : {
          "ipconfig0" = "ip=${config.ip_address}/${var.network.subnet_mask},gw=${var.network.gateway}"
        }
        ipconfig0 = lookup(
          length(keys(try(config.ipconfigs, {}))) > 0 ? config.ipconfigs : {
            "ipconfig0" = "ip=${config.ip_address}/${var.network.subnet_mask},gw=${var.network.gateway}"
          },
          "ipconfig0",
          null
        )
        labels      = try(config.labels, {})
        taints      = try(config.taints, [])
        manage_pci  = try(config.manage_pci, false)
        pci_devices = try(config.pci_devices, [])
        # Default disk configuration for workers
        disks = length(keys(config.disks)) > 0 ? config.disks : {
          "scsi0" = {
            type     = "disk"
            slot     = "scsi0"
            storage  = var.storage.name
            size     = try(config.disk_size, "50G")
            format   = "qcow2"
            cache    = "writethrough"
            iothread = false
            backup   = true
          }
        }
      })
    }
  )

  # Separate by node type for Talos configuration
  control_plane_nodes = {
    for name, config in local.all_nodes : name => config
    if config.node_type == "controlplane"
  }

  worker_nodes = {
    for name, config in local.all_nodes : name => config
    if config.node_type != "controlplane"
  }

  # Extract IPs for easy access
  control_plane_ips = [
    for config in local.control_plane_nodes : config.ip_address
  ]

  worker_ips = [
    for config in local.worker_nodes : config.ip_address
  ]

  # Determine cluster endpoint
  cluster_endpoint = var.cluster_endpoint != null ? var.cluster_endpoint : local.control_plane_ips[0]
}
