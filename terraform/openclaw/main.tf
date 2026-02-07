terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.94"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "proxmox" {
  insecure = var.proxmox_insecure

  # Endpoint and authentication via environment variables:
  #   PROXMOX_VE_ENDPOINT="https://pve:8006"
  #   PROXMOX_VE_API_TOKEN="user@pam!terraform=xxxxxxxx-..."
}

resource "proxmox_virtual_environment_vm" "openclaw" {
  node_name = var.proxmox_node
  vm_id     = var.vm_id > 0 ? var.vm_id : null
  name      = var.vm_name

  clone {
    vm_id = var.template_id
  }

  cpu {
    cores = var.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.memory
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    dns {
      servers = split(" ", var.dns_servers)
    }

    user_account {
      username = var.ssh_user
      keys     = [trimspace(var.ssh_public_key)]
    }
  }

  started = true
}

locals {
  vm_ip = split("/", var.ip_address)[0]
}

resource "null_resource" "openclaw_provision" {
  depends_on = [proxmox_virtual_environment_vm.openclaw]

  triggers = {
    vm_id = proxmox_virtual_environment_vm.openclaw.vm_id
  }

  # Wait for SSH to become available
  provisioner "local-exec" {
    command = <<-EOT
      for i in $(seq 1 30); do
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
          -i ${var.ansible_ssh_private_key} \
          ${var.ssh_user}@${local.vm_ip} 'echo ready' && exit 0
        echo "Waiting for SSH... attempt $i/30"
        sleep 10
      done
      echo "SSH not available after 30 attempts" && exit 1
    EOT
  }

  # Write extra-vars to a temp JSON file and run Ansible
  provisioner "local-exec" {
    working_dir = "${path.module}/ansible"
    command     = <<-EOT
      cat > /tmp/openclaw-extra-vars.json <<'JSONEOF'
      ${jsonencode({
        openclaw_gateway_port = tostring(var.openclaw_gateway_port)
        ssh_user              = var.ssh_user
      })}
      JSONEOF
      ansible-playbook playbook.yml \
        -i '${local.vm_ip},' \
        -u ${var.ssh_user} \
        --private-key ${var.ansible_ssh_private_key} \
        -e @/tmp/openclaw-extra-vars.json
      RESULT=$?
      rm -f /tmp/openclaw-extra-vars.json
      exit $RESULT
    EOT
  }
}
