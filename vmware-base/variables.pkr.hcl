# ──────────────────────────────────────────────────────────────
# variables.pkr.hcl — Input variables for VMware vSphere image
# ──────────────────────────────────────────────────────────────

# ── vCenter Connection ───────────────────────────────────────

variable "vcenter_server" {
  type        = string
  description = "FQDN or IP of the vCenter Server."
}

variable "vcenter_username" {
  type        = string
  sensitive   = true
  description = "vCenter login username."
}

variable "vcenter_password" {
  type        = string
  sensitive   = true
  description = "vCenter login password."
}

variable "vcenter_insecure" {
  type        = bool
  default     = false
  description = "Skip TLS verification (set true for self-signed certs in labs)."
}

# ── vSphere Placement ───────────────────────────────────────

variable "datacenter" {
  type    = string
  default = "dc01"
}

variable "cluster" {
  type    = string
  default = "cluster01"
}

variable "datastore" {
  type    = string
  default = "datastore01"
}

variable "network" {
  type    = string
  default = "VM Network"
}

variable "folder" {
  type    = string
  default = "Templates"
}

# ── VM Hardware ──────────────────────────────────────────────

variable "vm_name" {
  type    = string
  default = "ubuntu-2404-template"
}

variable "cpus" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 4096
  description = "RAM in MB."
}

variable "disk_size" {
  type    = number
  default = 40960
  description = "Disk size in MB."
}

# ── ISO ──────────────────────────────────────────────────────

variable "iso_url" {
  type        = string
  default     = ""
  description = "URL to download the Ubuntu ISO (used if iso_paths is empty)."
}

variable "iso_paths" {
  type        = list(string)
  default     = []
  description = "Datastore path to the ISO, e.g. [datastore01] ISOs/ubuntu-24.04.1-live-server-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "none"
}

# ── Tags ─────────────────────────────────────────────────────

variable "environment" {
  type    = string
  default = "production"
}

variable "team" {
  type    = string
  default = "platform"
}
