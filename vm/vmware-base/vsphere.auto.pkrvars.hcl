# ──────────────────────────────────────────────────────────────
# vsphere.auto.pkrvars.hcl — VMware vSphere environment overrides
# ──────────────────────────────────────────────────────────────
# Files ending in .auto.pkrvars.hcl are loaded automatically.
# Adjust these values for your vSphere environment.
#
# Sensitive credentials MUST be set via environment variables:
#   export PKR_VAR_vcenter_server="vcsa.example.com"
#   export PKR_VAR_vcenter_username="administrator@vsphere.local"
#   export PKR_VAR_vcenter_password="your-password"
# ──────────────────────────────────────────────────────────────

datacenter  = "dc01"
cluster     = "cluster01"
datastore   = "datastore01"
network     = "VM Network"
folder      = "Templates"

vm_name     = "ubuntu-2404-template"
cpus        = 2
memory      = 4096
disk_size   = 40960

environment = "staging"
team        = "platform-engineering"

# ISO — set one of these:
# iso_paths = ["[datastore01] ISOs/ubuntu-24.04.1-live-server-amd64.iso"]
# iso_url   = "https://releases.ubuntu.com/24.04.1/ubuntu-24.04.1-live-server-amd64.iso"
