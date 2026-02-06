# ──────────────────────────────────────────────────────────────
# proxmox.pkr.hcl — Proxmox VE: Ubuntu 24.04 VM Template
# ──────────────────────────────────────────────────────────────
#
# Builds a VM template on Proxmox VE from an Ubuntu Server ISO.
# Uses cloud-init autoinstall for unattended OS installation,
# then provisions with shell scripts.
#
# The ISO must be pre-uploaded to Proxmox storage.
# Autoinstall config is served via Packer's built-in HTTP server.
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
# Boots from an ISO, waits for autoinstall to complete, then
# runs provisioners over SSH and converts the VM to a template.

source "proxmox-iso" "ubuntu" {
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
  bios    = "ovmf"

  cores   = var.cores
  sockets = var.sockets
  memory  = var.memory

  scsi_controller = "virtio-scsi-pci"

  efi_config {
    efi_storage_pool  = var.disk_storage_pool
    efi_type          = "4m"
    pre_enrolled_keys = true
  }

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

  # ── Autoinstall via HTTP ──
  # Packer spins up a temporary HTTP server to serve the
  # cloud-init autoinstall file from the http/ directory.
  http_directory = "${path.root}/http"

  # Boot command: drops to GRUB command line, manually loads
  # kernel + initrd with autoinstall parameter, then boots.
  boot_wait = "10s"
  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/'",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot",
    "<enter>"
  ]

  # ── SSH (post-install) ──
  ssh_username           = "packer"
  ssh_password           = "packer"
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 100

  # ── Output ──
  template_description = "Ubuntu 24.04 base template — built by Packer on ${local.timestamp}"
}

# ── Build ────────────────────────────────────────────────────

build {
  name    = "proxmox-ubuntu"
  sources = ["source.proxmox-iso.ubuntu"]

  # ── Step 1: Wait for cloud-init ────────────────────────────

  provisioner "shell" {
    inline = [
      "echo '>>> Waiting for cloud-init...'",
      "sudo cloud-init status --wait",
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

  provisioner "shell" {
    inline = [
      "echo '>>> Installing QEMU Guest Agent...'",
      "sudo apt-get install -y qemu-guest-agent",
      "sudo systemctl enable qemu-guest-agent",
      "sudo systemctl start qemu-guest-agent",
    ]
  }

  # ── Step 4: Cleanup ────────────────────────────────────────

  provisioner "shell" {
    scripts = [
      "${path.root}/../../shared/scripts/cleanup.sh",
    ]
    execute_command = "chmod +x {{ .Path }}; sudo bash {{ .Path }}"
  }

  # ── Step 5: Reset machine-id (critical for cloning) ────────
  # Without this, all VMs cloned from the template would share
  # the same machine-id, causing DHCP and systemd-journal issues.

  provisioner "shell" {
    inline = [
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo ln -s /etc/machine-id /var/lib/dbus/machine-id",
      "echo '>>> machine-id reset for template cloning.'"
    ]
  }
}
