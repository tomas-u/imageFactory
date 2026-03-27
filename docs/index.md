# Image Factory — VM & Container Images

A production-ready collection of golden images for VMs (Packer) and containers
(Podman). VM templates cover AWS, Azure, VMware, and Proxmox (Ubuntu + Debian).
Container images provide hardened bases for Nginx, .NET 8, and Python 3.12.

---

## Project Structure

```
imageFactory/
├── README.md
│
├── vm/                                 # Packer VM templates
│   ├── aws-webserver/                  #   AWS AMI — Nginx + Node.js web server
│   │   ├── webserver.pkr.hcl
│   │   ├── variables.pkr.hcl
│   │   └── webserver.auto.pkrvars.hcl
│   │
│   ├── azure-base/                     #   Azure Managed Image — hardened Ubuntu
│   │   ├── base.pkr.hcl
│   │   ├── variables.pkr.hcl
│   │   └── base.auto.pkrvars.hcl
│   │
│   ├── vmware-base/                    #   VMware vSphere — Ubuntu 24.04 template
│   │   ├── vsphere.pkr.hcl
│   │   ├── variables.pkr.hcl
│   │   ├── vsphere.auto.pkrvars.hcl
│   │   └── http/
│   │       └── user-data
│   │
│   ├── proxmox-ubuntu/                 #   Proxmox VE — Ubuntu 24.04 template
│   │   ├── proxmox.pkr.hcl
│   │   ├── variables.pkr.hcl
│   │   ├── proxmox.auto.pkrvars.hcl
│   │   └── http/
│   │       ├── user-data
│   │       └── meta-data
│   │
│   └── proxmox-debian/                 #   Proxmox VE — Debian 13 (Trixie) template
│       ├── proxmox.pkr.hcl
│       ├── variables.pkr.hcl
│       ├── proxmox.auto.pkrvars.hcl
│       └── http/
│           └── preseed.cfg
│
├── containers/                         # Podman container images
│   ├── nginx-base/                     #   Hardened Nginx on Alpine
│   │   └── Containerfile
│   ├── dotnet-base/                    #   .NET 8 ASP.NET (chiseled/distroless)
│   │   └── Containerfile
│   └── python-base/                    #   Python 3.12 slim with tini
│       └── Containerfile
│
├── shared/                             # Reusable provisioning assets
│   ├── scripts/
│   │   ├── base-setup.sh
│   │   ├── podman-install.sh
│   │   ├── monitoring-agent.sh
│   │   └── cleanup.sh
│   └── ansible/
│       ├── playbook.yml
│       └── roles/
│           └── hardening/
│               └── tasks/
│                   └── main.yml
│
└── .github/
    └── workflows/
        ├── packer-pipeline.yml         # VM CI: validate → build → publish
        └── container-pipeline.yml      # Container CI: lint → build → push
```

---

## Prerequisites

| Tool       | Version   | Purpose                              |
|------------|-----------|--------------------------------------|
| Packer     | ≥ 1.10    | VM image builder                     |
| Ansible    | ≥ 2.15    | Configuration management provisioner |
| Podman     | ≥ 4.x     | Container image builder              |
| hadolint   | ≥ 2.12    | Containerfile linter                 |
| Terraform  | ≥ 1.6     | (Optional) deploy infra from images  |
| AWS CLI    | ≥ 2.x     | AWS credentials & AMI management     |
| Azure CLI  | ≥ 2.x     | Azure credentials & image management |
| govc       | ≥ 0.34    | (Optional) vSphere CLI               |

Install Packer:

```bash
# macOS
brew install hashicorp/tap/packer

# Linux (Debian/Ubuntu)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install packer

# Verify
packer version
```

---

## Quick Start (AWS Example)

```bash
# 1. Navigate to the AWS template
cd vm/aws-webserver

# 2. Initialise plugins (downloads the AWS builder)
packer init .

# 3. Validate the template
packer validate .

# 4. (Optional) inspect variables
packer inspect .

# 5. Build the AMI
#    Pass credentials via env vars or AWS CLI profile
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."

packer build .
#   → outputs the AMI ID when done, e.g. ami-0abc123def456
```

---

## Quick Start (Azure)

```bash
# 1. Authenticate to Azure (interactive — for CI use a Service Principal)
az login

# 2. Set your subscription ID
export PKR_VAR_subscription_id="your-subscription-id"

# For CI / Service Principal auth, also set:
#   export PKR_VAR_tenant_id="..."
#   export PKR_VAR_client_id="..."
#   export PKR_VAR_client_secret="..."

# 3. Navigate to the Azure template
cd vm/azure-base

# 4. Initialise plugins and validate
packer init .
packer validate .

# 5. Build the managed image
packer build .
#   → outputs the image name in the configured resource group
```

---

## Quick Start (VMware vSphere)

VMware builds install Ubuntu from an ISO using cloud-init autoinstall
(unattended). The autoinstall config is in `vm/vmware-base/http/user-data`.

```bash
# 1. Set vCenter credentials (never commit these)
export PKR_VAR_vcenter_server="vcsa.example.com"
export PKR_VAR_vcenter_username="administrator@vsphere.local"
export PKR_VAR_vcenter_password="your-password"

# 2. Edit vm/vmware-base/vsphere.auto.pkrvars.hcl for your environment:
#    datacenter, cluster, datastore, network, ISO path, etc.

# 3. Navigate to the VMware template
cd vm/vmware-base

# 4. Initialise plugins and validate
packer init .
packer validate .

# 5. Build the VM template
packer build .
#   → creates a VM template on vCenter
```

The boot process: Packer creates a VM, attaches the ISO, types a boot command
that points the Ubuntu installer at `http://<packer-ip>:<port>/` for
autoinstall configuration, then waits for SSH to become available (~10-15 min).

---

## Quick Start (Proxmox Ubuntu 24.04)

Proxmox Ubuntu builds install Ubuntu from an ISO using cloud-init autoinstall
(unattended), similar to VMware. The autoinstall config is in `vm/proxmox-ubuntu/http/user-data`.

```bash
# 1. Set Proxmox API credentials (never commit these)
#    Option A — API token (recommended):
export PKR_VAR_proxmox_url="https://proxmox.example.com:8006/api2/json"
export PKR_VAR_proxmox_username="packer@pve!packer-token"
export PKR_VAR_proxmox_token="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

#    Option B — Password:
# export PKR_VAR_proxmox_username="packer@pve"
# export PKR_VAR_proxmox_password="your-password"

# 2. Edit vm/proxmox-ubuntu/proxmox.auto.pkrvars.hcl for your environment:
#    node, storage pools, network bridge, ISO path, etc.

# 3. Navigate to the Proxmox template
cd vm/proxmox-ubuntu

# 4. Initialise plugins and validate
packer init .
packer validate .

# 5. Build the VM template
packer build .
#   → creates a VM template on Proxmox VE
```

The boot process: Packer creates a VM, attaches the ISO, drops to the GRUB
command line and manually loads the kernel with an autoinstall parameter
pointing at `http://<packer-ip>:<port>/` for configuration, then waits for
SSH to become available (~10-15 min).

---

## Quick Start (Proxmox Debian 13)

Proxmox Debian builds install Debian 13 (Trixie) from a netinst ISO using
preseed for unattended installation. The preseed config is in
`vm/proxmox-debian/http/preseed.cfg`.

```bash
# 1. Set Proxmox API credentials (same as Ubuntu — never commit these)
#    Option A — API token (recommended):
export PKR_VAR_proxmox_url="https://proxmox.example.com:8006/api2/json"
export PKR_VAR_proxmox_username="packer@pve!packer-token"
export PKR_VAR_proxmox_token="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

#    Option B — Password:
# export PKR_VAR_proxmox_username="packer@pve"
# export PKR_VAR_proxmox_password="your-password"

# 2. Edit vm/proxmox-debian/proxmox.auto.pkrvars.hcl for your environment:
#    node, storage pools, network bridge, ISO path, etc.

# 3. Navigate to the Proxmox Debian template
cd vm/proxmox-debian

# 4. Initialise plugins and validate
packer init .
packer validate .

# 5. Build the VM template
packer build .
#   → creates a Debian 13 VM template on Proxmox VE
```

The boot process: Packer creates a VM, attaches the Debian netinst ISO, drops
to the GRUB command line and manually loads the installer kernel with a preseed
URL pointing at `http://<packer-ip>:<port>/preseed.cfg`, then waits for SSH to
become available (~10-15 min).

---

## Quick Start (Container Images)

Build container images locally with Podman:

```bash
# Build all three images
make build-containers

# Or build individually
make build-container-nginx
make build-container-dotnet
make build-container-python

# Lint all Containerfiles
make lint-containers
```

Use in downstream projects:

```dockerfile
# Nginx — static site
FROM ghcr.io/your-org/nginx-base:latest
COPY dist/ /usr/share/nginx/html/

# .NET 8 — ASP.NET service
FROM ghcr.io/your-org/dotnet-base:latest
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "MyApp.dll"]

# Python 3.12 — Flask/FastAPI app
FROM ghcr.io/your-org/python-base:latest
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

---

## Make Targets

A `Makefile` is provided for common operations:

```bash
# VM targets
make help                  # Show all targets
make validate-all          # Validate all five VM platforms
make build-aws             # Build the AWS AMI
make lint                  # Run shellcheck on shared scripts
make fmt                   # Auto-format all HCL files

# Container targets
make build-containers      # Build all container images
make build-container-nginx # Build nginx-base image
make lint-containers       # Lint Containerfiles with hadolint
make push-containers       # Push all images to registry
```

---

## Key Packer Concepts

### Template anatomy (HCL)

```
┌─────────────────────────────────────────────────────────┐
│  packer { }          Plugin requirements & settings     │
├─────────────────────────────────────────────────────────┤
│  variable "..." { }  Input parameters                   │
├─────────────────────────────────────────────────────────┤
│  data "..." "..." {} Dynamic data lookups (e.g. AMI ID) │
├─────────────────────────────────────────────────────────┤
│  source "..." "..." {}  HOW to build (builder config)   │
├─────────────────────────────────────────────────────────┤
│  build { }           WHAT to build                      │
│    ├─ sources = [...]   Reference one or more sources   │
│    ├─ provisioner "..."  Install software / configure   │
│    └─ post-processor "..." After-build actions          │
└─────────────────────────────────────────────────────────┘
```

### Workflow

```
packer init      Download plugins declared in packer { }
       ↓
packer validate   Syntax + config validation (no cloud calls)
       ↓
packer build      Launch temp VM → provision → snapshot → destroy temp VM
       ↓
                  Output: AMI / Managed Image / VM Template
```

---

## Updating Images

Golden image updates follow this cycle:

```
Code change (script, playbook, var)
       ↓
PR review  →  `packer validate` in CI
       ↓
Merge to main  →  `packer build` in CI
       ↓
New image version published
       ↓
Terraform / ASG picks up new image ID
       ↓
Rolling deploy of new instances
```

The CI pipeline in `.github/workflows/packer-pipeline.yml` automates this end-to-end.

---

## Security Notes

- **No secrets in templates.** Use environment variables or a vault.
- **Hardening scripts** apply CIS benchmark items (SSH, kernel params, audit).
- **Cleanup scripts** remove build artifacts, SSH keys, and logs before snapshot.
- **Container images** run as non-root with minimal packages installed.
- The BSL license (since Packer 1.10+) permits internal production use;
  review the license if you plan to embed Packer in a commercial product.

---

## Further Reading

- [Packer Docs](https://developer.hashicorp.com/packer)
- [HCP Packer (image registry)](https://developer.hashicorp.com/hcp/docs/packer)
- [Packer + Terraform golden image pipeline](https://developer.hashicorp.com/packer/tutorials/cloud-production/golden-image-with-hcp-packer)
- [Podman Docs](https://docs.podman.io/)
- [hadolint — Dockerfile/Containerfile linter](https://github.com/hadolint/hadolint)
