# ──────────────────────────────────────────────────────────────
# variables.pkr.hcl — Input variables for Proxmox Debian image
# ──────────────────────────────────────────────────────────────

# ── Proxmox Connection ─────────────────────────────────────

variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL. Format: https://host:8006/api2/json"
}

variable "proxmox_username" {
  type        = string
  sensitive   = true
  description = "Proxmox username. Format: user@realm (e.g. packer@pve) or user@realm!tokenid for token auth."
}

variable "proxmox_token" {
  type        = string
  default     = ""
  sensitive   = true
  description = "API token secret (recommended for CI). Leave empty to use password auth."
}

variable "proxmox_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Password for username. Leave empty when using token auth."
}

variable "proxmox_insecure" {
  type        = bool
  default     = false
  description = "Skip TLS verification (set true for self-signed certs in labs)."
}

# ── Placement & ISO ────────────────────────────────────────

variable "proxmox_node" {
  type        = string
  default     = "pve"
  description = "Proxmox node name where the VM is built."
}

variable "vm_id" {
  type        = number
  default     = 0
  description = "Proxmox VM ID. Set to 0 for auto-assignment."
}

variable "iso_file" {
  type        = string
  description = "Proxmox ISO path. Format: storage:iso/filename.iso (e.g. local:iso/debian-13.3.0-amd64-netinst.iso)"
}

variable "iso_storage_pool" {
  type        = string
  default     = "local"
  description = "Proxmox storage pool where ISOs are stored."
}

# ── VM Hardware ────────────────────────────────────────────

variable "vm_name" {
  type    = string
  default = "debian-13-template"
}

variable "cores" {
  type    = number
  default = 2
}

variable "sockets" {
  type    = number
  default = 1
}

variable "memory" {
  type        = number
  default     = 4096
  description = "RAM in MB."
}

variable "disk_size" {
  type        = string
  default     = "40G"
  description = "Root disk size (e.g. 40G)."
}

variable "disk_storage_pool" {
  type        = string
  default     = "local-lvm"
  description = "Proxmox storage pool for the VM disk."
}

variable "disk_type" {
  type        = string
  default     = "scsi"
  description = "Disk bus type (scsi, virtio, sata, ide)."
}

variable "network_bridge" {
  type        = string
  default     = "vmbr0"
  description = "Proxmox network bridge."
}

variable "vlan_tag" {
  type        = number
  default     = 0
  description = "VLAN tag. Set to 0 for no VLAN."
}

# ── Cloud-Init & Guest Agent ──────────────────────────────

variable "cloud_init" {
  type        = bool
  default     = true
  description = "Add a cloud-init drive to the template."
}

variable "cloud_init_storage_pool" {
  type        = string
  default     = "local-lvm"
  description = "Storage pool for the cloud-init drive."
}

variable "qemu_agent" {
  type        = bool
  default     = true
  description = "Enable QEMU guest agent (required for IP detection)."
}

# ── Tags ─────────────────────────────────────────────────

variable "environment" {
  type        = string
  default     = "production"
  description = "Target environment tag (production, staging, development)."

  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "environment must be production, staging, or development."
  }
}

variable "team" {
  type    = string
  default = "platform"
}
