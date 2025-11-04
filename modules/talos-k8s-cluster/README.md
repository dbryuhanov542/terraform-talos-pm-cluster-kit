# Talos Kubernetes Cluster (Proxmox)

Terraform module that builds a Talos-based Kubernetes cluster on Proxmox VE by orchestrating virtual machines and applying Talos machine configurations.

## Highlights

- 🚀 Spins up control plane and worker pools through the reusable `00-proxmox-vm` module
- ⚙️ Supports static IPs or custom `ipconfig*` maps per node (cloud-init optional)
- 🎛️ Optional PCI passthrough per node via `manage_pci` and `pci_devices`
- 🔧 Talos machine patches for both control plane and workers
- 🔌 KubePrism toggle with configurable port

## Usage

```hcl
module "talos_cluster" {
  # Module published at github.com/dbryuhanov542/terraform-talos-pm-cluster-kit
  source = "github.com/dbryuhanov542/terraform-talos-pm-cluster-kit//modules/talos-k8s-cluster"

  cluster_name  = "lab-k8s"
  talos_version = "v1.10.4"

  network = {
    bridge      = "vmbr0"
    subnet_mask = 24
    gateway     = "192.168.1.1"
    nameservers = ["192.168.1.53"]
  }

  control_planes = {
    cp1 = {
      vm_id        = 400
      proxmox_node = "pve-1"
      ip_address   = "192.168.1.201"
      cpu_cores    = 4
      memory       = 4096
      disks = {
        scsi0 = {
          storage = "vmdata"
          size    = "50G"
        }
      }
    }
  }

  workers = {
    worker1 = {
      vm_id        = 410
      proxmox_node = "pve-1"
      ip_address   = "192.168.1.211"
      cpu_cores    = 4
      memory       = 8192
      labels = {
        "node-role" = "worker"
      }
    }
    gpu1 = {
      vm_id        = 420
      proxmox_node = "pve-2"
      ip_address   = "192.168.1.212"
      cpu_cores    = 8
      memory       = 16384
      manage_pci   = true
      pci_devices = [
        {
          mapping_id = "nvidia-rtx"
          primary_gpu = true
        }
      ]
    }
  }

  vm_template = {
    name = "talos-template"
  }

  storage = {
    name = "vmdata"
  }
}
```

## Key Inputs

| Variable | Type | Default | Notes |
|----------|------|---------|-------|
| `cluster_name` | string | n/a | Cluster identifier used for VM names and Talos resources. |
| `cluster_endpoint` | string | `null` | VIP / DNS entry for the API server. Defaults to the first control plane IP. |
| `network` | object | n/a | Shared networking data (bridge, gateway, nameservers, etc.). |
| `control_planes` | map(object) | n/a | Control plane nodes (requires at least one). |
| `workers` | map(object) | `{}` | Worker nodes. |
| `vm_template` | object | n/a | Base Proxmox template (name, pool, full_clone). |
| `storage` | object | n/a | Default storage for VM disks/cloud-init ISO. |
| `cloud_init` | object | `{ enabled = true, user = "talos" }` | Toggle cloud-init disk and configure credentials/DNS. |
| `talos_version` | string | `"v1.10.4"` | Talos release for secrets and machine config generation. |
| `talos_control_plane_patches` | list(string) | `[]` | Extra YAML snippets merged into control plane nodes. |
| `talos_worker_patches` | list(string) | `[]` | Extra YAML snippets merged into worker nodes. |

Each node entry supports:

- `ip_address`, optional `ipconfigs` overrides (`{ "ipconfig0" = "ip=dhcp" }`)
- `disk_size` shortcut plus explicit `disks` map (per-slot overrides)
- `pci_devices` mirroring the `proxmox-vm` module schema and `manage_pci`
- `labels` & `taints` (workers)

## Outputs

| Output | Description |
|--------|-------------|
| `cluster_name` | Cluster name. |
| `cluster_endpoint` | API endpoint used for Talos/Kubernetes. |
| `kubeconfig` | Raw kubeconfig (sensitive). |
| `talosconfig` | Talos client configuration (sensitive). |
| `control_plane_ips` | List of control plane node IPs. |
| `worker_ips` | List of worker node IPs. |
| `vm_info` | Map with VM metadata (ID, IP, node type, Proxmox node). |

## Notes

- Talos resources assume `talosctl` connectivity; consider adding a `time_sleep` or health check between VM creation and configuration apply if your environment is slow to boot.
- `manage_pci` defaults to `false`; enable it only when your Proxmox provider build can safely touch passthrough devices.
- When `cloud_init.enabled = false`, no cloud-init disk is attached and the module stops passing cloud-init credentials to the VM module.
