# ──────────────────────────────────────────────────────────────
# proxmox.pkr.hcl — Proxmox VE: Debian 13 (Trixie) VM Template
# ──────────────────────────────────────────────────────────────
#
# Builds a VM template on Proxmox VE from a Debian 13 netinst ISO.
# Uses preseed for unattended OS installation, then provisions
# with shell scripts.
#
# The ISO must be pre-uploaded to Proxmox storage.
# Preseed config is served via Packer's built-in HTTP server.
#
# Auth options (pick one):
#   a) API Token (recommended):  set PKR_VAR_proxmox_token
#   b) Password:                 set PKR_VAR_proxmox_password
#
# Usage:
#   packer init .
#   packer validate .
#   packer build .
# ──────────────────────────────────────────────────────────────

packer {
  required_version = ">= 1.10.0"

  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = ">= 1.2.3"
    }
  }
}

# ── Locals ───────────────────────────────────────────────────

locals {
  timestamp = formatdate("YYYYMMDD-hhmmss", timestamp())
  vm_name   = "${var.vm_name}-${local.timestamp}"
}

# ── Source: Proxmox ISO Builder ──────────────────────────────
# Boots from a Debian netinst ISO, runs preseed for unattended
# install, then provisions over SSH and converts to a template.

source "proxmox-iso" "debian" {
  # ── Proxmox Connection ──
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token != "" ? var.proxmox_token : null
  password                 = var.proxmox_password != "" ? var.proxmox_password : null
  insecure_skip_tls_verify = var.proxmox_insecure
  node                     = var.proxmox_node

  # ── VM Settings ──
  vm_id   = var.vm_id != 0 ? var.vm_id : null
  vm_name = local.vm_name
  os      = "l26"
  bios    = "seabios"
  machine = "q35"

  cores   = var.cores
  sockets = var.sockets
  memory  = var.memory

  scsi_controller = "virtio-scsi-pci"

  disks {
    storage_pool = var.disk_storage_pool
    type         = var.disk_type
    disk_size    = var.disk_size
    discard      = true
  }

  network_adapters {
    model    = "virtio"
    bridge   = var.network_bridge
    vlan_tag = var.vlan_tag != 0 ? var.vlan_tag : null
    firewall = false
  }

  # ── ISO ──
  boot_iso {
    iso_file         = var.iso_file
    iso_storage_pool = var.iso_storage_pool
    unmount          = true
  }

  # ── Cloud-Init ──
  cloud_init              = var.cloud_init
  cloud_init_storage_pool = var.cloud_init_storage_pool

  # ── QEMU Guest Agent ──
  qemu_agent = var.qemu_agent

  # ── Preseed via HTTP ──
  # Packer spins up a temporary HTTP server to serve the
  # preseed.cfg file from the http/ directory.
  http_directory = "${path.root}/http"

  # Boot command: at the ISOLINUX menu, select "Install" (text),
  # press Tab to edit kernel params, append preseed URL, Enter to boot.
  boot_wait = "5s"
  boot_command = [
    "<down><wait>",
    "<tab>",
    " auto=true priority=critical",
    " preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg",
    " locale=en_US.UTF-8 keymap=se hostname=packer-template domain=",
    " netcfg/choose_interface=auto",
    " --- quiet",
    "<enter>"
  ]

  # ── SSH (post-install) ──
  ssh_username           = "packer"
  ssh_password           = "packer"
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 100

  # ── Output ──
  template_description = "Debian 13 (Trixie) base template — built by Packer on ${local.timestamp}"
}

# ── Build ────────────────────────────────────────────────────

build {
  name    = "proxmox-debian"
  sources = ["source.proxmox-iso.debian"]

  # ── Step 1: Wait for system to settle ──────────────────────

  provisioner "shell" {
    inline = [
      "echo '>>> Waiting for system to settle...'",
      "sleep 5",
      "echo '>>> Ready.'"
    ]
  }

  # ── Step 2: Base Setup ─────────────────────────────────────

  provisioner "shell" {
    scripts = [
      "${path.root}/../../shared/scripts/base-setup.sh",
      "${path.root}/../../shared/scripts/podman-install.sh",
      "${path.root}/../../shared/scripts/monitoring-agent.sh",
    ]
    execute_command = "chmod +x {{ .Path }}; sudo bash {{ .Path }}"
  }

  # ── Step 3: Install QEMU Guest Agent ───────────────────────
  # The agent is udev-activated on Debian 13 (no [Install] section),
  # so enable/start is unnecessary — Proxmox starts it automatically.

  provisioner "shell" {
    inline = [
      "echo '>>> Ensuring QEMU Guest Agent is installed...'",
      "sudo apt-get install -y qemu-guest-agent",
    ]
  }

  # ── Step 4: Reset machine-id (critical for cloning) ────────
  # Without this, all VMs cloned from the template would share
  # the same machine-id, causing DHCP and systemd-journal issues.
  # Must run BEFORE cleanup, which locks the packer user.

  provisioner "shell" {
    inline = [
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo ln -s /etc/machine-id /var/lib/dbus/machine-id",
      "echo '>>> machine-id reset for template cloning.'"
    ]
  }

  # ── Step 5: Cleanup (must be last — locks packer user) ────

  provisioner "shell" {
    scripts = [
      "${path.root}/../../shared/scripts/cleanup.sh",
    ]
    execute_command = "chmod +x {{ .Path }}; sudo bash {{ .Path }}"
  }
}
