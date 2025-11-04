# Homelab Example Environment

This directory shows a minimal Terraform environment that reuses the
`modules/talos-k8s-cluster` module to build a Talos-based Kubernetes cluster on
Proxmox.  The example is intentionally self-contained:

- no remote backend configuration (state stays local by default);
- placeholder IP addresses from the documentation ranges (192.0.2.0/24);
- a single control-plane node and a single worker node.

Use it as a starting point when publishing the modules or sharing them with
others.

## Getting Started

1. Copy the sample variables file and fill in your Proxmox credentials.

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Adjust the VM IDs, nodes, network details and template/storage names in
   `main.tf` (or create your own `terraform.tfvars` entries overriding the
   `locals`).

3. Initialise and plan/apply the environment:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

   > The example keeps `bootstrap_enabled = true`, so the first apply will run
   > the Talos bootstrap step.

## Overriding the defaults

The `locals { ... }` block in `main.tf` holds the example configuration.  You
can either edit those values directly or override them from `terraform.tfvars`
by supplying maps that match the module interface, for example:

```hcl
cluster_name = "prod-k8s"

control_planes = {
  cp1 = {
    vm_id        = 510
    proxmox_node = "pve-1"
    ip_address   = "10.0.0.11"
    cpu_cores    = 4
    memory       = 8192
  }
  cp2 = {
    vm_id        = 511
    proxmox_node = "pve-2"
    ip_address   = "10.0.0.12"
    cpu_cores    = 4
    memory       = 8192
  }
}
```

Refer to the module README for the complete list of supported fields
(`modules/talos-k8s-cluster/README.md`).
