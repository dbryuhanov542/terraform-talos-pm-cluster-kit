# 00-modules/01-k8s-cluster/outputs.tf

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = var.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = local.cluster_endpoint
}

output "kubeconfig" {
  description = "Kubernetes cluster kubeconfig"
  value       = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive   = true
}

output "talosconfig" {
  description = "Complete Talos client configuration"
  value       = <<-EOT
    context: ${var.cluster_name}
    contexts:
      ${var.cluster_name}:
        endpoints:
          - ${join("\n          - ", [for node in local.control_plane_nodes : node.ip_address])}
        ca: |
          ${indent(10, talos_machine_secrets.cluster_secrets.client_configuration.ca_certificate)}
        crt: |
          ${indent(10, talos_machine_secrets.cluster_secrets.client_configuration.client_certificate)}
        key: |
          ${indent(10, talos_machine_secrets.cluster_secrets.client_configuration.client_key)}
  EOT
  sensitive   = true
}

output "control_plane_ips" {
  description = "Control plane node IP addresses"
  value       = local.control_plane_ips
}

output "worker_ips" {
  description = "Worker node IP addresses"
  value = [
    for config in local.worker_nodes : config.ip_address
  ]
}

output "vm_info" {
  description = "Information about created VMs"
  value = {
    for name, config in local.all_nodes : name => {
      vm_id        = config.vm_id
      ip_address   = config.ip_address
      node_type    = config.node_type
      proxmox_node = config.proxmox_node
    }
  }
}