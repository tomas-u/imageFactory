# ──────────────────────────────────────────────────────────────
# proxmox.auto.pkrvars.hcl — Proxmox Debian environment overrides
# ──────────────────────────────────────────────────────────────
# Files ending in .auto.pkrvars.hcl are loaded automatically.
# Adjust these values for your Proxmox environment.
#
# Sensitive credentials MUST be set via environment variables:
#   export PKR_VAR_proxmox_url="https://proxmox.example.com:8006/api2/json"
#   export PKR_VAR_proxmox_username="packer@pve!packer-token"
#   export PKR_VAR_proxmox_token="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#
# Or for password auth:
#   export PKR_VAR_proxmox_username="packer@pve"
#   export PKR_VAR_proxmox_password="your-password"
# ──────────────────────────────────────────────────────────────

proxmox_node       = "pve"
vm_id              = 9901
vm_name            = "debian-13-template"
cores              = 2
sockets            = 1
memory             = 4096
disk_size          = "40G"
disk_storage_pool  = "local-lvm"
network_bridge     = "vmbr0"
proxmox_insecure   = true

environment        = "production"
team               = "streampower-devops"

# ISO — set this to your Proxmox ISO path:
iso_file = "local:iso/debian-13.3.0-amd64-netinst.iso"
