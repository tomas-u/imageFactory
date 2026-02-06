# ──────────────────────────────────────────────────────────────
# Makefile — Image Factory
# ──────────────────────────────────────────────────────────────
.DEFAULT_GOAL := help
SHELL := /bin/bash

# ── Container variables ──────────────────────────────────────
REGISTRY ?= ghcr.io
OWNER    ?= $(shell git remote get-url origin 2>/dev/null | sed -n 's|.*github\.com[:/]\([^/]*\)/.*|\1|p' | tr '[:upper:]' '[:lower:]')
TAG      ?= latest

# ══════════════════════════════════════════════════════════════
#  VM Image Targets (Packer)
# ══════════════════════════════════════════════════════════════

# ── Init ──────────────────────────────────────────────────────

.PHONY: init-aws init-azure init-vmware init-proxmox init-proxmox-debian

init-aws: ## Download plugins for AWS template
	cd vm/aws-webserver && packer init .

init-azure: ## Download plugins for Azure template
	cd vm/azure-base && packer init .

init-vmware: ## Download plugins for VMware template
	cd vm/vmware-base && packer init .

init-proxmox: ## Download plugins for Proxmox Ubuntu template
	cd vm/proxmox-ubuntu && packer init .

init-proxmox-debian: ## Download plugins for Proxmox Debian template
	cd vm/proxmox-debian && packer init .

# ── Validate ──────────────────────────────────────────────────

.PHONY: validate-aws validate-azure validate-vmware validate-proxmox validate-proxmox-debian validate-all

validate-aws: init-aws ## Validate AWS template
	cd vm/aws-webserver && packer validate .

validate-azure: init-azure ## Validate Azure template (uses placeholder subscription_id)
	cd vm/azure-base && packer validate -var "subscription_id=12345678-1234-1234-1234-123456789012" .

validate-vmware: init-vmware ## Validate VMware template (uses placeholder vCenter vars)
	cd vm/vmware-base && packer validate \
		-var "vcenter_server=placeholder.local" \
		-var "vcenter_username=placeholder" \
		-var "vcenter_password=placeholder" \
		.

validate-proxmox: init-proxmox ## Validate Proxmox Ubuntu template (uses placeholder vars)
	cd vm/proxmox-ubuntu && packer validate \
		-var "proxmox_url=https://placeholder.local:8006/api2/json" \
		-var "proxmox_username=placeholder@pve" \
		-var "proxmox_token=placeholder" \
		-var "iso_file=local:iso/placeholder.iso" \
		.

validate-proxmox-debian: init-proxmox-debian ## Validate Proxmox Debian template (uses placeholder vars)
	cd vm/proxmox-debian && packer validate \
		-var "proxmox_url=https://placeholder.local:8006/api2/json" \
		-var "proxmox_username=placeholder@pve" \
		-var "proxmox_token=placeholder" \
		-var "iso_file=local:iso/placeholder.iso" \
		.

validate-all: validate-aws validate-azure validate-vmware validate-proxmox validate-proxmox-debian ## Validate all templates

# ── Build ─────────────────────────────────────────────────────

.PHONY: build-aws build-azure build-vmware build-proxmox build-proxmox-debian

build-aws: init-aws ## Build AWS AMI (requires AWS credentials)
	cd vm/aws-webserver && packer build .

build-azure: init-azure ## Build Azure image (requires az login or SP credentials)
	cd vm/azure-base && packer build .

build-vmware: init-vmware ## Build VMware template (requires vCenter credentials)
	cd vm/vmware-base && packer build .

build-proxmox: init-proxmox ## Build Proxmox Ubuntu template (requires Proxmox API credentials)
	cd vm/proxmox-ubuntu && packer build .

build-proxmox-debian: init-proxmox-debian ## Build Proxmox Debian template (requires Proxmox API credentials)
	cd vm/proxmox-debian && packer build .

# ── Lint ──────────────────────────────────────────────────────

.PHONY: lint

lint: ## Run shellcheck on all shared scripts
	shellcheck shared/scripts/*.sh

# ── Format ────────────────────────────────────────────────────

.PHONY: fmt fmt-check

fmt: ## Auto-format all Packer HCL files
	packer fmt vm/aws-webserver/
	packer fmt vm/azure-base/
	packer fmt vm/vmware-base/
	packer fmt vm/proxmox-ubuntu/
	packer fmt vm/proxmox-debian/

fmt-check: ## Check Packer HCL formatting (no changes)
	packer fmt -check -diff vm/aws-webserver/
	packer fmt -check -diff vm/azure-base/
	packer fmt -check -diff vm/vmware-base/
	packer fmt -check -diff vm/proxmox-ubuntu/
	packer fmt -check -diff vm/proxmox-debian/

# ══════════════════════════════════════════════════════════════
#  Container Image Targets (Podman)
# ══════════════════════════════════════════════════════════════

.PHONY: build-container-nginx build-container-dotnet build-container-python build-containers lint-containers push-containers

build-container-nginx: ## Build nginx-base container image
	podman build -t $(REGISTRY)/$(OWNER)/nginx-base:$(TAG) containers/nginx-base/

build-container-dotnet: ## Build dotnet-base container image
	podman build -t $(REGISTRY)/$(OWNER)/dotnet-base:$(TAG) containers/dotnet-base/

build-container-python: ## Build python-base container image
	podman build -t $(REGISTRY)/$(OWNER)/python-base:$(TAG) containers/python-base/

build-containers: build-container-nginx build-container-dotnet build-container-python ## Build all container images

lint-containers: ## Lint Containerfiles with hadolint
	hadolint containers/nginx-base/Containerfile
	hadolint containers/dotnet-base/Containerfile
	hadolint containers/python-base/Containerfile

push-containers: ## Push all container images to registry
	podman push $(REGISTRY)/$(OWNER)/nginx-base:$(TAG)
	podman push $(REGISTRY)/$(OWNER)/dotnet-base:$(TAG)
	podman push $(REGISTRY)/$(OWNER)/python-base:$(TAG)

# ── Help ──────────────────────────────────────────────────────

.PHONY: help

help: ## Show this help message
	@echo "Image Factory — available targets:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}'
	@echo ""
