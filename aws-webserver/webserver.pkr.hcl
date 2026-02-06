# ──────────────────────────────────────────────────────────────
# webserver.pkr.hcl — AWS AMI: Nginx + Node.js Web Server
# ──────────────────────────────────────────────────────────────
#
# Builds a hardened Ubuntu 24.04 AMI with:
#   • Nginx reverse proxy
#   • Node.js (LTS) runtime
#   • Prometheus node_exporter
#   • CIS-style OS hardening
#
# Usage:
#   packer init .
#   packer validate .
#   packer build .
# ──────────────────────────────────────────────────────────────

# ── Plugin Requirements ──────────────────────────────────────

packer {
  required_version = ">= 1.10.0"

  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.3.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.0"
    }
  }
}

# ── Data Source: Find Latest Ubuntu 24.04 AMI ────────────────
# Instead of hard-coding an AMI ID, we dynamically look up the
# latest official Canonical image. This keeps builds current.

data "amazon-ami" "ubuntu" {
  filters = {
    name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
    architecture        = "x86_64"
  }
  most_recent = true
  owners      = ["099720109477"] # Canonical
  region      = var.aws_region
}

# ── Locals ───────────────────────────────────────────────────
# Computed values used throughout the template.

locals {
  timestamp = formatdate("YYYYMMDD-hhmmss", timestamp())
  ami_name  = "${var.ami_name_prefix}-${local.timestamp}"

  common_tags = {
    Name        = local.ami_name
    Environment = var.environment
    Team        = var.team
    Builder     = "packer"
    BuildTime   = local.timestamp
    SourceAMI   = data.amazon-ami.ubuntu.id
  }
}

# ── Source: Amazon EBS Builder ───────────────────────────────
# Defines HOW to create the image: launch a temp instance,
# connect via SSH, then create an AMI from the root EBS volume.

source "amazon-ebs" "webserver" {
  # ── AWS & Region ──
  region = var.aws_region

  # ── Base Image ──
  source_ami = data.amazon-ami.ubuntu.id

  # ── Build Instance ──
  instance_type = var.instance_type
  ssh_username  = var.ssh_username
  ssh_timeout   = "10m"

  # Networking (optional — omit for default VPC)
  vpc_id    = var.vpc_id != "" ? var.vpc_id : null
  subnet_id = var.subnet_id != "" ? var.subnet_id : null
  associate_public_ip_address = true

  # ── Output AMI ──
  ami_name        = local.ami_name
  ami_description = var.ami_description
  ami_regions     = var.ami_regions
  ami_users       = var.ami_users

  # Encrypt the root volume of the output AMI
  encrypt_boot = true

  # EBS-optimised for better I/O during build
  ebs_optimized = true

  # Root volume configuration
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  # Tags applied to the output AMI and its snapshots
  tags          = local.common_tags
  snapshot_tags = local.common_tags

  # Tags for the *temporary* build instance (useful for cost tracking)
  run_tags = merge(local.common_tags, {
    Name = "packer-build-${local.timestamp}"
  })
}

# ── Build ────────────────────────────────────────────────────
# Defines WHAT to install and configure inside the image.
# Provisioners run in order, top to bottom.

build {
  name    = "webserver"
  sources = ["source.amazon-ebs.webserver"]

  # ── Step 1: Wait for Cloud-Init ────────────────────────────
  # Ubuntu AMIs run cloud-init on first boot which holds the
  # apt lock. Wait for it to finish before we do anything.

  provisioner "shell" {
    inline = [
      "echo '>>> Waiting for cloud-init to complete...'",
      "cloud-init status --wait",
      "echo '>>> Cloud-init done.'"
    ]
  }

  # ── Step 2: Base Setup & Hardening ─────────────────────────
  # Upload and run the shared base-setup script.

  provisioner "shell" {
    scripts = [
      "${path.root}/../shared/scripts/base-setup.sh",
    ]
    execute_command  = "chmod +x {{ .Path }}; sudo bash {{ .Path }}"
    expect_disconnect = false
  }

  # ── Step 3: Install Docker ─────────────────────────────────

  provisioner "shell" {
    scripts = [
      "${path.root}/../shared/scripts/docker-install.sh",
    ]
    execute_command = "chmod +x {{ .Path }}; sudo bash {{ .Path }}"
  }

  # ── Step 4: Install Node.js ────────────────────────────────

  provisioner "shell" {
    inline = [
      "echo '>>> Installing Node.js ${var.node_version}.x ...'",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg",
      "echo \"deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${var.node_version}.x nodistro main\" | sudo tee /etc/apt/sources.list.d/nodesource.list > /dev/null",
      "sudo apt-get update -y",
      "sudo apt-get install -y nodejs",
      "node --version",
      "npm --version"
    ]
  }

  # ── Step 5: Install & Configure Nginx ──────────────────────

  provisioner "shell" {
    inline = [
      "echo '>>> Installing Nginx...'",
      "sudo apt-get install -y nginx",
      "sudo systemctl enable nginx",
    ]
  }

  # Upload a custom nginx config if one was provided
  provisioner "file" {
    source      = var.nginx_config_path != "" ? var.nginx_config_path : "/dev/null"
    destination = "/tmp/nginx-custom.conf"
  }

  provisioner "shell" {
    inline = [
      "if [ -s /tmp/nginx-custom.conf ]; then",
      "  echo '>>> Applying custom nginx config'",
      "  sudo cp /tmp/nginx-custom.conf /etc/nginx/nginx.conf",
      "  sudo nginx -t",
      "fi",
      "rm -f /tmp/nginx-custom.conf"
    ]
  }

  # ── Step 6: Monitoring Agent ───────────────────────────────

  provisioner "shell" {
    scripts = [
      "${path.root}/../shared/scripts/monitoring-agent.sh",
    ]
    execute_command = "chmod +x {{ .Path }}; sudo bash {{ .Path }}"
  }

  # ── Step 7: Ansible Hardening (optional) ───────────────────
  # Uses the Ansible provisioner to apply CIS hardening tasks.
  # Requires Ansible installed on the *build machine* (not the VM).

  provisioner "ansible" {
    playbook_file = "${path.root}/../shared/ansible/playbook.yml"
    user          = var.ssh_username
    use_proxy     = false

    extra_arguments = [
      "--extra-vars", "target_env=${var.environment}",
      "--ssh-extra-args", "-o StrictHostKeyChecking=no"
    ]
  }

  # ── Step 8: Final Cleanup ──────────────────────────────────
  # ALWAYS run cleanup last. Removes logs, SSH keys, temp files
  # to produce a lean, secure snapshot.

  provisioner "shell" {
    scripts = [
      "${path.root}/../shared/scripts/cleanup.sh",
    ]
    execute_command    = "chmod +x {{ .Path }}; sudo bash {{ .Path }}"
    expect_disconnect  = false
  }

  # ── Post-Processors ────────────────────────────────────────
  # Generate a manifest JSON with the AMI ID, region, and build
  # metadata. Useful for downstream Terraform or CD pipelines.

  post-processor "manifest" {
    output     = "${path.root}/build-manifest.json"
    strip_path = true
  }
}
