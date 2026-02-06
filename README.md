# Packer Templates — Practical DevOps Guide

A production-ready collection of HashiCorp Packer templates for building golden
VM images across AWS, Azure, and VMware. Each template follows immutable
infrastructure and DevSecOps best practices.

---

## Project Structure

```
packer-templates/
├── README.md                        # ← You are here
│
├── aws-webserver/                   # AWS AMI — Nginx + Node.js web server
│   ├── webserver.pkr.hcl            #   Main template (source + build)
│   ├── variables.pkr.hcl            #   Input variables & defaults
│   └── webserver.auto.pkrvars.hcl   #   Environment-specific overrides
│
├── azure-base/                      # Azure Managed Image — hardened Ubuntu
│   ├── base.pkr.hcl
│   ├── variables.pkr.hcl
│   └── base.auto.pkrvars.hcl
│
├── vmware-base/                     # VMware vSphere — Ubuntu 24.04 template
│   ├── vsphere.pkr.hcl
│   ├── variables.pkr.hcl
│   └── http/
│       └── user-data                #   Cloud-init autoinstall config
│
├── shared/                          # Reusable provisioning assets
│   ├── scripts/
│   │   ├── base-setup.sh            #   OS hardening & base packages
│   │   ├── docker-install.sh        #   Docker CE installation
│   │   ├── monitoring-agent.sh      #   Prometheus node_exporter
│   │   └── cleanup.sh              #   Image cleanup / shrink
│   └── ansible/
│       ├── playbook.yml             #   Main Ansible playbook
│       └── roles/
│           └── hardening/
│               └── tasks/
│                   └── main.yml     #   CIS-style OS hardening tasks
│
└── ci/
    └── github-actions.yml           # CI pipeline: validate → build → publish
```

---

## Prerequisites

| Tool       | Version   | Purpose                              |
|------------|-----------|--------------------------------------|
| Packer     | ≥ 1.10    | Image builder                        |
| Ansible    | ≥ 2.15    | Configuration management provisioner |
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
cd aws-webserver

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

The CI pipeline in `ci/github-actions.yml` automates this end-to-end.

---

## Security Notes

- **No secrets in templates.** Use environment variables or a vault.
- **Hardening scripts** apply CIS benchmark items (SSH, kernel params, audit).
- **Cleanup scripts** remove build artifacts, SSH keys, and logs before snapshot.
- The BSL license (since Packer 1.10+) permits internal production use;
  review the license if you plan to embed Packer in a commercial product.

---

## Further Reading

- [Packer Docs](https://developer.hashicorp.com/packer)
- [HCP Packer (image registry)](https://developer.hashicorp.com/hcp/docs/packer)
- [Packer + Terraform golden image pipeline](https://developer.hashicorp.com/packer/tutorials/cloud-production/golden-image-with-hcp-packer)
