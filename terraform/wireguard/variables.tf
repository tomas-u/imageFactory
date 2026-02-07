variable "proxmox_insecure" {
  description = "Skip TLS certificate verification"
  type        = bool
  default     = false
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

variable "template_id" {
  description = "VM ID of the source template to clone"
  type        = number
  default     = 9901
}

variable "vm_id" {
  description = "VM ID for the new VM (0 = auto-assign)"
  type        = number
  default     = 9100
}

variable "vm_name" {
  description = "Name of the VM"
  type        = string
  default     = "wireguard"
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "memory" {
  description = "RAM in MB"
  type        = number
  default     = 2048
}

variable "ip_address" {
  description = "Static IP address with CIDR (e.g. 192.168.1.80/24)"
  type        = string
  default     = "192.168.1.80/24"
}

variable "gateway" {
  description = "Default gateway"
  type        = string
  default     = "192.168.1.1"
}

variable "dns_servers" {
  description = "DNS servers (space-separated)"
  type        = string
  default     = "1.1.1.1 8.8.8.8"
}

variable "ssh_user" {
  description = "Default user created by cloud-init"
  type        = string
  default     = "tomas"
}

variable "ssh_public_key" {
  description = "SSH public key for cloud-init user access"
  type        = string
}

# --- WireGuard / wg-easy ---

variable "wg_host" {
  description = "Public IP or hostname that WireGuard clients connect to"
  type        = string
}

variable "wg_password_hash" {
  description = "Bcrypt hash for the wg-easy web UI password"
  type        = string
  sensitive   = true
}

variable "wg_port" {
  description = "WireGuard UDP listen port"
  type        = number
  default     = 51820
}

variable "wg_ui_port" {
  description = "wg-easy web UI TCP port"
  type        = number
  default     = 51821
}

variable "wg_default_address" {
  description = "WireGuard client address range (e.g. 10.0.0.x)"
  type        = string
  default     = "10.0.0.x"
}

variable "wg_default_dns" {
  description = "DNS server pushed to WireGuard clients"
  type        = string
  default     = "1.1.1.1"
}

variable "duckdns_token" {
  description = "DuckDNS API token for dynamic DNS updates"
  type        = string
  sensitive   = true
}

variable "duckdns_domain" {
  description = "DuckDNS subdomain (without .duckdns.org)"
  type        = string
  default     = "streampower"
}

variable "ansible_ssh_private_key" {
  description = "Path to SSH private key for Ansible"
  type        = string
  default     = "~/.ssh/id_ed25519"
}
