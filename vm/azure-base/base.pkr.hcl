# ──────────────────────────────────────────────────────────────
# base.pkr.hcl — Azure Managed Image: Hardened Ubuntu 24.04
# ──────────────────────────────────────────────────────────────
#
# Builds a hardened Ubuntu base image on Azure with:
#   • Security updates applied
#   • Podman
#   • Prometheus node_exporter
#   • CIS-style OS hardening
#
# Auth options (pick one):
#   a) Interactive:  az login (then omit client_id/secret)
#   b) Service Principal:  set PKR_VAR_client_id / PKR_VAR_client_secret
#
# Usage:
#   packer init .
#   packer validate .
#   packer build .
# ──────────────────────────────────────────────────────────────

packer {
  required_version = ">= 1.10.0"

  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = ">= 2.1.0"
    }
  }
}

# ── Locals ───────────────────────────────────────────────────

locals {
  timestamp  = formatdate("YYYYMMDD-hhmmss", timestamp())
  image_name = "${var.image_name_prefix}-${local.timestamp}"

  common_tags = {
    Environment = var.environment
    Team        = var.team
    Builder     = "packer"
    BuildTime   = local.timestamp
  }
}

# ── Source: Azure ARM Builder ────────────────────────────────
# Creates a temp VM from a Marketplace image, provisions it,
# then generalises (sysprep) and captures a Managed Image.

source "azure-arm" "ubuntu" {
  # ── Authentication ──
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id != "" ? var.tenant_id : null
  client_id       = var.client_id != "" ? var.client_id : null
  client_secret   = var.client_secret != "" ? var.client_secret : null

  # If no SP credentials are provided, the plugin falls back to
  # Azure CLI auth (az login). Good for local development.

  # ── Base Image (Marketplace) ──
  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "ubuntu-24_04-lts"
  image_sku       = "server"

  # ── Build VM ──
  location = var.location
  vm_size  = var.vm_size

  os_disk_size_gb = var.os_disk_size_gb

  # ── Networking ──
  # By default Packer creates a temporary resource group, VNet,
  # NIC, and public IP. These are cleaned up after the build.
  # For private builds, set virtual_network_name / subnet_name.

  # ── Output ──
  managed_image_name                = local.image_name
  managed_image_resource_group_name = var.resource_group

  # Shared Image Gallery (optional — uncomment to publish there)
  # shared_image_gallery_destination {
  #   subscription        = var.subscription_id
  #   resource_group      = var.resource_group
  #   gallery_name        = "sig_golden_images"
  #   image_name          = "ubuntu-base"
  #   image_version       = "1.0.${formatdate("YYYYMMDD", timestamp())}"
  #   replication_regions = ["westeurope", "northeurope"]
  # }

  # ── Communication ──
  communicator = "ssh"
  ssh_username = "packer"

  # Tags on the temporary build resources (cost tracking)
  azure_tags = local.common_tags
}

# ── Build ────────────────────────────────────────────────────

build {
  name    = "azure-ubuntu-base"
  sources = ["source.azure-arm.ubuntu"]

  # ── Step 1: Wait for apt lock ──────────────────────────────

  provisioner "shell" {
    inline = [
      "echo '>>> Waiting for cloud-init & apt...'",
      "cloud-init status --wait",
      "while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 2; done",
      "while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 2; done",
      "echo '>>> Ready.'"
    ]
  }

  # ── Step 2: Base Setup & Hardening ─────────────────────────

  provisioner "shell" {
    scripts = [
      "${path.root}/../../shared/scripts/base-setup.sh",
      "${path.root}/../../shared/scripts/podman-install.sh",
      "${path.root}/../../shared/scripts/monitoring-agent.sh",
    ]
    execute_command = "chmod +x {{ .Path }}; sudo bash {{ .Path }}"
  }

  # ── Step 3: Azure-Specific — Install Azure Agent ───────────

  provisioner "shell" {
    inline = [
      "echo '>>> Installing Azure CLI...'",
      "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash",
      "",
      "echo '>>> Ensuring walinuxagent is up to date...'",
      "sudo apt-get install -y walinuxagent",
    ]
  }

  # ── Step 4: Cleanup ────────────────────────────────────────

  provisioner "shell" {
    scripts = [
      "${path.root}/../../shared/scripts/cleanup.sh",
    ]
    execute_command = "chmod +x {{ .Path }}; sudo bash {{ .Path }}"
  }

  # ── Step 5: Deprovision (Azure-specific) ───────────────────
  # The waagent -deprovision step is REQUIRED for Azure to
  # generalise the image so it can be used to spawn new VMs.

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; sudo bash -c '{{ .Path }}'"
    inline = [
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
    expect_disconnect = true
  }

  # ── Post-Processor: Manifest ───────────────────────────────

  post-processor "manifest" {
    output     = "${path.root}/build-manifest.json"
    strip_path = true
  }
}
