# ──────────────────────────────────────────────────────────────
# variables.pkr.hcl — Input variables for the Azure base image
# ──────────────────────────────────────────────────────────────

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID. Set via env: PKR_VAR_subscription_id"
}

variable "tenant_id" {
  type        = string
  default     = ""
  description = "Azure AD tenant ID. Can also authenticate via az login."
}

variable "client_id" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Service principal client ID (for CI). Leave blank for interactive login."
}

variable "client_secret" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Service principal secret (for CI). Leave blank for interactive login."
}

# ── Resource Group & Location ────────────────────────────────

variable "location" {
  type        = string
  default     = "westeurope"
  description = "Azure region for the build VM and output image."
}

variable "resource_group" {
  type        = string
  default     = "rg-packer-images"
  description = "Resource group to store the managed image."
}

# ── Image Settings ───────────────────────────────────────────

variable "image_name_prefix" {
  type        = string
  default     = "ubuntu-base"
  description = "Prefix for the managed image name."
}

variable "vm_size" {
  type        = string
  default     = "Standard_B2s"
  description = "Azure VM size for the build instance."
}

variable "os_disk_size_gb" {
  type        = number
  default     = 30
  description = "Root OS disk size in GB."
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
