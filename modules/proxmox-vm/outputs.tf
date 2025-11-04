output "vm_id" {
  description = "VM ID"
  value       = proxmox_vm_qemu.vm.vmid
}

output "vm_name" {
  description = "VM name"
  value       = proxmox_vm_qemu.vm.name
}

output "vm_node" {
  description = "Proxmox node where VM is created"
  value       = proxmox_vm_qemu.vm.target_node
}

output "vm_status" {
  description = "VM status"
  value       = try(jsondecode(jsonencode(proxmox_vm_qemu.vm)).status, null)
}

output "vm_ipv4_address" {
  description = "VM IPv4 address"
  value       = proxmox_vm_qemu.vm.default_ipv4_address
}

output "vm_ssh_host" {
  description = "SSH host for connection"
  value       = proxmox_vm_qemu.vm.ssh_host
}

output "vm_ssh_port" {
  description = "SSH port for connection"
  value       = proxmox_vm_qemu.vm.ssh_port
}

# DNS Outputs
output "dns_enabled" {
  description = "Whether DNS record creation is enabled"
  value       = local.dns_enabled
}

output "dns_fqdn" {
  description = "Full DNS name (FQDN) of the created A-record"
  value       = local.dns_ready ? "${local.dns_hostname}.${trimsuffix(var.dns.zone, ".")}" : null
}

output "dns_ip" {
  description = "IP address used in DNS A-record"
  value       = local.dns_ready ? local.extracted_ip : null
}

output "dns_record_id" {
  description = "DNS A-record resource ID (for debugging)"
  value       = local.dns_ready ? dns_a_record_set.vm_dns[0].id : null
}
