output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_virtual_environment_vm.wireguard.vm_id
}

output "vm_name" {
  description = "VM name"
  value       = proxmox_virtual_environment_vm.wireguard.name
}

output "ip_address" {
  description = "Static IP address"
  value       = var.ip_address
}

output "wg_server_endpoint" {
  description = "WireGuard endpoint for client configs"
  value       = "${var.wg_host}:${var.wg_port}"
}

output "wg_ui_url" {
  description = "wg-easy web management UI"
  value       = "http://${local.vm_ip}:${var.wg_ui_port}"
}
