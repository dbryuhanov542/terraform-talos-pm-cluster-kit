# Terraform Modules for Proxmox + Talos

This repository packages two reusable Terraform modules for homelab and small-team infrastructure on top of Proxmox VE:

- `modules/proxmox-vm` — a flexible wrapper around `proxmox_vm_qemu` with disk, network, PCI and DNS helpers.
- `modules/talos-k8s-cluster` — orchestrates a Talos-based Kubernetes cluster by composing the VM module and Talos resources.

Example usage lives under `examples/`. Everything is scrubbed of real credentials so you can publish this repository directly to GitHub and accept contributions.

## Requirements

- Terraform `>= 1.12.2`
- Proxmox VE with API access (token-based credentials recommended)
- Terraform providers:
  - `telmate/proxmox` `3.0.2-rc03` (or newer compatible release)
  - `hashicorp/dns` `~> 3.4` when DNS automation is enabled
  - `siderolabs/talos` `0.9.0-alpha.0` for the cluster module
- Talos CLI (`talosctl`) if you want to interact with the generated Talos and Kubernetes configs

## Repository Layout

- `modules/proxmox-vm` — the base VM module with docs and input/output definitions.
- `modules/talos-k8s-cluster` — high-level cluster module that consumes `proxmox-vm`.
- `examples/homelab-example` — minimal environment showing how to wire the modules together.
- `.gitignore` — keeps Terraform state and secret overrides out of version control.

## Getting Started

1. Install Terraform (matching the versions declared in each module).
2. Optionally initialise the example environment:

   ```bash
   cd examples/homelab-example
   cp terraform.tfvars.example terraform.tfvars
   # Fill in your Proxmox credentials
   terraform init
   terraform plan
   ```

3. Point your configurations at `github.com/dbryuhanov542/terraform-talos-pm-cluster-kit//modules/...` (or keep relative paths if you vendor the modules).

## Using the Modules

### Proxmox VM module

```hcl
module "app_vm" {
  source = "github.com/dbryuhanov542/terraform-talos-pm-cluster-kit//modules/proxmox-vm?ref=main"

  name         = "app-01"
  vm_id        = 210
  node         = "pve-1"
  clone_template = "debian-12-template"

  disks = [{
    type    = "disk"
    slot    = "scsi0"
    storage = "local-lvm"
    size    = "40G"
  }]

  networks = {
    net0 = {
      bridge = "vmbr0"
    }
  }
}
```

Set `ref=` to a tagged release (e.g. `?ref=v0.1.0`) once you create one to avoid tracking `main`.

### Talos Kubernetes cluster module

```hcl
module "talos_cluster" {
  source = "github.com/dbryuhanov542/terraform-talos-pm-cluster-kit//modules/talos-k8s-cluster?ref=main"

  cluster_name  = "homelab-k8s"
  cluster_endpoint = "192.168.1.100"

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
    }
  }

  workers = {}

  vm_template = {
    name       = "talos-template"
    full_clone = true
  }

  storage = {
    name = "local-lvm"
  }
}
```

Provide credentials through `.tfvars` (ignored by Git) or environment variables before running `terraform apply`. The example environment demonstrates the expected variables.

## Contributing

Issues and pull requests are welcome once the repository is live. Please include:

- a short description of the infrastructure scenario you tested;
- `terraform fmt` and `terraform validate` output;
- any Talos or Proxmox provider version constraints that changed.

## Security Notes

The example environment stays local and uses placeholder IP networks (`192.0.2.0/24`). Never commit real kubeconfigs, Talos configs, or `.tfvars` with credentials—`.gitignore` already blocks the common patterns, so keep your sensitive overrides in untracked files.
