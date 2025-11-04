# Proxmox VM Module

Terraform module for creating and managing virtual machines on Proxmox VE with comprehensive configuration options and security best practices.

## Features

- ✅ **Multi-disk support**: attach any number of disks across different Proxmox storages
- ✅ **Optional PCI passthrough**: gate device passthrough behind `manage_pci` to avoid provider bugs
- ✅ **Cloud-init integration**: deliver initial users, SSH keys and networking data
- ✅ **Flexible networking**: configure VLAN, MTU, rate limits, queues only when you need them
- ✅ **DNS automation**: optionally create A-records via the HashiCorp DNS provider

## Usage

### Basic VM

```hcl
module "basic_vm" {
  # Module published at github.com/dbryuhanov542/terraform-talos-pm-cluster-kit
  source = "github.com/dbryuhanov542/terraform-talos-pm-cluster-kit//modules/proxmox-vm"

  # Basic configuration
  name   = "web-server-01"
  vm_id  = 100
  node   = "pve-1"
  
  # Resources
  cpu_cores = 2
  memory    = 4096
  
  # Template
  clone_template = "debian-12-template"
  
  # Disks
  disks = [
    {
      type    = "disk"
      slot    = "scsi0"
      storage = "local-lvm"
      size    = "50G"
      format  = "raw"
    }
  ]
  
  # Network
  networks = {
    net0 = {
      bridge = "vmbr0"
      model  = "virtio"
    }
  }
}
```

### Kubernetes Node with GPU

```hcl
module "k8s_gpu_node" {
  source = "github.com/dbryuhanov542/terraform-talos-pm-cluster-kit//modules/proxmox-vm"

  name   = "k8s-gpu-worker-01"
  vm_id  = 250
  node   = "pve-1"
  manage_pci = true  # enable only if your Proxmox provider handles PCI reconfiguration safely
  
  # Enhanced resources for GPU workloads
  cpu_cores = 8
  memory    = 16384
  
  # Template
  clone_template = "talos-template"
  
  # Multiple disks
  disks = [
    {
      type     = "disk"
      slot     = "scsi0"
      storage  = "vmdata"
      size     = "100G"
      format   = "raw"
      iothread = true
    },
    {
      type    = "disk"
      slot    = "scsi1"
      storage = "fast-ssd"
      size    = "500G"
      format  = "raw"
    }
  ]
  
  # GPU passthrough
  pci_devices = [
    {
      id         = 0
      mapping_id = "nvidia-rtx-4090"
      pcie       = true
      rombar     = true
    }
  ]
  
  # Specialized network
  networks = {
    net0 = {
      bridge   = "vmbr0"
      model    = "virtio"
      firewall = false
      queues   = 4
    }
  }
  
  # Labels for Kubernetes
  tags = "k8s,gpu,worker,terraform"
}
```

### High-Availability Database Server

```hcl
module "database_server" {
  source = "github.com/dbryuhanov542/terraform-talos-pm-cluster-kit//modules/proxmox-vm"

  name = "db-primary-01"
  vm_id = 300
  node  = "pve-1"
  
  # High-performance configuration
  cpu_cores   = 8
  cpu_sockets = 2
  cpu_type    = "host"
  memory      = 32768
  balloon     = 16384
  
  # Clone from database template
  clone_template = "debian-12-db-template"
  
  # High-performance storage
  disks = [
    {
      type     = "disk"
      slot     = "scsi0" 
      storage  = "nvme-pool"
      size     = "100G"
      format   = "raw"
      cache    = "writethrough"
      iothread = true
      backup   = true
    },
    {
      type     = "disk"
      slot     = "scsi1"
      storage  = "nvme-pool" 
      size     = "500G"
      format   = "raw"
      cache    = "writethrough"
      iothread = true
      backup   = true
    }
  ]
  
  # Redundant network interfaces
  networks = {
    net0 = {
      bridge = "vmbr0"
      model  = "virtio"
      queues = 8
    }
    net1 = {
      bridge = "vmbr1"
      model  = "virtio"
      queues = 8
    }
  }
  
  # High availability settings
  onboot_startup = true
  protection     = true
  
  # Cloud-init for automation
  os_type     = "cloud-init"
  ci_user     = "dbadmin"
  nameserver  = "192.168.1.1"
  searchdomain = "company.local"
  
  tags = "database,ha,production,terraform"
}
```

## Input Variables

Key inputs (see [`variables.tf`](variables.tf) for the complete list):

| Variable | Type | Default | Notes |
|----------|------|---------|-------|
| `name` | string | `"terraform-vm"` | Human-readable VM name. |
| `vm_id` | number | `null` | Numerical VMID (set to `null` to let Proxmox assign). |
| `node` | string | `"pve"` | Target Proxmox node name. |
| `clone_template` | string | `"ubuntu-2204-cloudinit"` | Template or VM to clone. |
| `disks` | list(object) | `[]` | One or more disks; see examples below. |
| `networks` | map(object) | `{ net0 = { bridge = "vmbr0" } }` | Only `bridge` is required; VLAN, MTU, rate, etc. are optional. |
| `pci_devices` | list(object) | `[]` | PCI devices to attach (only used when `manage_pci = true`). |
| `manage_pci` | bool | `false` | Toggle PCI passthrough management to avoid provider bugs. |
| `machine` | string | `null` | Proxmox machine type (inherit template when unset). |
| `os_type` | string | `"cloud-init"` | Must align with your base template. |
| `ci_user` / `ci_password` / `ssh_keys` | string | `""` | Cloud-init credentials and SSH keys. |
| `dns` | object | `null` | Optional HashiCorp DNS record configuration. |

## Outputs

| Output | Description |
|--------|-------------|
| `vm_id` | Numeric Proxmox VMID. |
| `vm_name` | VM name. |
| `vm_node` | Target node. |
| `vm_status` | VM status when the provider exposes it (falls back to `null` with older builds). |
| `vm_ipv4_address` | Primary IPv4 address (when available). |
| `vm_ssh_host` / `vm_ssh_port` | Values emitted by the provider when the guest exposes SSH (cloud-init images, most Linux distros). |
| `dns_*` | DNS record status when `var.dns` is configured. |

> ℹ️ Talos Linux and other SSH-less appliances will leave `vm_ssh_*` outputs empty. This is expected even when cloud-init is in use.

## Disk Configuration

The module supports multiple disk types and configurations:

### Disk Types

- **disk**: Standard VM disk
- **cdrom**: CD/DVD ROM drive  
- **cloudinit**: Cloud-init configuration drive

### Storage Options

- **local-lvm**: Local LVM storage
- **vmdata**: ZFS dataset
- **nfs-storage**: NFS shared storage
- **ceph-storage**: Ceph distributed storage

### Example Disk Configurations

```hcl
# Basic OS disk
{
  type    = "disk"
  slot    = "scsi0"
  storage = "local-lvm"
  size    = "50G"
  format  = "raw"
}

# High-performance database disk
{
  type     = "disk"
  slot     = "scsi1"
  storage  = "nvme-pool"
  size     = "1000G" 
  format   = "raw"
  cache    = "writethrough"
  iothread = true
  discard  = true
  backup   = true
}

# Cloud-init drive
{
  type    = "cloudinit"
  slot    = "ide2"
  storage = "local-lvm"
}
```

## Network Configuration

### Basic Network Interface

```hcl
networks = {
  net0 = {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = false
  }
}
```

### Advanced Network with VLAN

```hcl
networks = {
  net0 = {
    bridge   = "vmbr0"
    model    = "virtio"
    vlan_tag = 100
    firewall = true
    queues   = 4
    rate     = 1000  # MB/s limit
  }
}
```

## PCI Passthrough

Set `manage_pci = true` to let the module send PCI configuration to Proxmox. This flag defaults to `false` because the upstream provider can still return `500` errors for unmanaged devices. Flip it on only after you confirm passthrough works reliably in your environment.

### GPU Passthrough

```hcl
pci_devices = [
  {
    id          = 0
    mapping_id  = "nvidia-rtx-4090"
    pcie        = true
    primary_gpu = true
    rombar      = true
  }
]
```

### Network Card Passthrough

```hcl  
pci_devices = [
  {
    id     = 0
    raw_id = "0000:01:00.0"
    pcie   = false
  }
]
```

## Cloud-init Configuration

### Basic Setup

```hcl
os_type      = "cloud-init"
ci_user      = "admin"
ci_password  = "secure-password"
nameserver   = "192.168.1.1"
searchdomain = "local"
ipconfig0    = "ip=192.168.1.100/24,gw=192.168.1.1"
```

### SSH Key Authentication

```hcl
os_type = "cloud-init"
ci_user = "admin"
ssh_keys = file("~/.ssh/id_rsa.pub")
```

## Security Best Practices

### Recommended Settings

```hcl
# Security hardening
protection = true  # Enable deletion protection
agent     = true   # Install QEMU guest agent
bios      = "ovmf" # Use UEFI for modern VMs
kvm       = true   # Enable KVM acceleration

# Network security
networks = {
  net0 = {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = true  # Enable VM-level firewall
  }
}

# Storage security
disks = [
  {
    type    = "disk"
    slot    = "scsi0"
    storage = "encrypted-pool"
    backup  = true
    discard = true  # Enable TRIM for SSDs
  }
]
```

## Monitoring Integration

The module includes built-in support for monitoring:

- **QEMU Guest Agent**: Provides VM metrics and control
- **Prometheus Integration**: VM metrics available via node_exporter
- **Backup Monitoring**: Track backup success/failure
- **Resource Monitoring**: CPU, memory, disk, network metrics

## Version Compatibility

| Module Version | Terraform | Proxmox VE | Provider |
|----------------|-----------|------------|----------|
| 2.0.x | >= 1.8.0 | >= 8.0 | ~> 3.0 |
| 1.3.x | >= 1.5.0 | >= 7.4 | ~> 2.9 |
| 1.2.x | >= 1.3.0 | >= 7.0 | ~> 2.7 |

## Changelog

### v2.0.0 - Enterprise Rewrite
- Complete module rewrite for enterprise use
- Added comprehensive disk configuration
- Enhanced PCI passthrough support
- Improved cloud-init integration
- Added security hardening options
- Enhanced documentation and examples

### v1.3.0 - PCI Passthrough
- Added PCI device passthrough support
- GPU passthrough capabilities
- Network card passthrough
- Enhanced hardware configuration

### v1.2.0 - Network Enhancements  
- Multiple network interface support
- VLAN tagging support
- Advanced network options
- Firewall integration

### v1.1.0 - Cloud-init Support
- Cloud-init drive support
- Automated provisioning
- SSH key injection
- Network configuration via cloud-init

### v1.0.0 - Initial Release
- Basic VM creation
- Template cloning
- Simple disk and network configuration
- Core Proxmox integration

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Update documentation
6. Submit a merge request

## License

This module is licensed under the MIT License. See [LICENSE](LICENSE) for details.
