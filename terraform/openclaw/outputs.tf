output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_virtual_environment_vm.openclaw.vm_id
}

output "vm_name" {
  description = "VM name"
  value       = proxmox_virtual_environment_vm.openclaw.name
}

output "ip_address" {
  description = "Static IP address"
  value       = var.ip_address
}

output "openclaw_url" {
  description = "Open Claw gateway UI"
  value       = "http://${local.vm_ip}:${var.openclaw_gateway_port}"
}
