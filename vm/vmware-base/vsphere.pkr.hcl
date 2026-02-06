# ──────────────────────────────────────────────────────────────
# vsphere.pkr.hcl — VMware vSphere: Ubuntu 24.04 VM Template
# ──────────────────────────────────────────────────────────────
#
# Builds a VM template on vSphere from an Ubuntu Server ISO.
# Uses cloud-init autoinstall for unattended OS installation,
# then provisions with shell scripts.
#
# The ISO is served from a datastore or downloaded from a URL.
# Autoinstall config is served via Packer's built-in HTTP server.
#
# Usage:
#   packer init .
#   packer validate -var-file="my-env.pkrvars.hcl" .
#   packer build   -var-file="my-env.pkrvars.hcl" .
# ──────────────────────────────────────────────────────────────

packer {
  required_version = ">= 1.10.0"

  required_plugins {
    vsphere = {
      source  = "github.com/hashicorp/vsphere"
      version = ">= 1.4.0"
    }
  }
}

# ── Locals ───────────────────────────────────────────────────

locals {
  timestamp = formatdate("YYYYMMDD-hhmmss", timestamp())
  vm_name   = "${var.vm_name}-${local.timestamp}"
}

# ── Source: vSphere ISO Builder ──────────────────────────────
# Boots from an ISO, waits for autoinstall to complete, then
# runs provisioners over SSH and converts the VM to a template.

source "vsphere-iso" "ubuntu" {
  # ── vCenter Connection ──
  vcenter_server      = var.vcenter_server
  username            = var.vcenter_username
  password            = var.vcenter_password
  insecure_connection = var.vcenter_insecure

  # ── Placement ──
  datacenter = var.datacenter
  cluster    = var.cluster
  datastore  = var.datastore
  folder     = var.folder

  # ── VM Settings ──
  vm_name              = local.vm_name
  guest_os_type        = "ubuntu64Guest"
  CPUs                 = var.cpus
  RAM                  = var.memory
  RAM_reserve_all      = false
  firmware             = "efi"
  disk_controller_type = ["pvscsi"]
  notes                = "Built by Packer on ${local.timestamp}"

  storage {
    disk_size             = var.disk_size
    disk_thin_provisioned = true
  }

  network_adapters {
    network      = var.network
    network_card = "vmxnet3"
  }

  # ── ISO ──
  iso_paths    = length(var.iso_paths) > 0 ? var.iso_paths : null
  iso_url      = length(var.iso_paths) == 0 ? var.iso_url : null
  iso_checksum = var.iso_checksum

  # Remove the ISO/CD-ROM after build
  remove_cdrom = true

  # ── Autoinstall via HTTP ──
  # Packer spins up a temporary HTTP server to serve the
  # cloud-init autoinstall file from the http/ directory.
  http_directory = "${path.root}/http"

  # Boot command: tells the Ubuntu installer where to find
  # the autoinstall config over HTTP.
  boot_wait = "5s"
  boot_command = [
    "<wait>e<down><down><down><end>",
    " autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/'",
    "<F10>"
  ]

  # ── SSH (post-install) ──
  ssh_username         = "packer"
  ssh_password         = "packer"       # Set in autoinstall; changed/removed by cleanup
  ssh_timeout          = "30m"
  ssh_handshake_attempts = 100

  # ── Output ──
  convert_to_template = true            # Convert VM → Template when done
}

# ── Build ────────────────────────────────────────────────────

build {
  name    = "vsphere-ubuntu"
  sources = ["source.vsphere-iso.ubuntu"]

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

  # ── Step 3: Install open-vm-tools ──────────────────────────

  provisioner "shell" {
    inline = [
      "echo '>>> Installing VMware Tools...'",
      "sudo apt-get install -y open-vm-tools",
      "sudo systemctl enable open-vm-tools",
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
