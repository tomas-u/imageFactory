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
  default     = 9101
}

variable "vm_name" {
  description = "Name of the VM"
  type        = string
  default     = "openclaw"
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "memory" {
  description = "RAM in MB"
  type        = number
  default     = 4096
}

variable "ip_address" {
  description = "Static IP address with CIDR (e.g. 192.168.1.81/24)"
  type        = string
  default     = "192.168.1.81/24"
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

variable "ansible_ssh_private_key" {
  description = "Path to SSH private key for Ansible"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

# --- Open Claw ---

variable "openclaw_gateway_port" {
  description = "Open Claw gateway UI TCP port"
  type        = number
  default     = 18789
}
