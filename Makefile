# ──────────────────────────────────────────────────────────────
# Makefile — Packer Image Factory
# ──────────────────────────────────────────────────────────────
.DEFAULT_GOAL := help
SHELL := /bin/bash

# ── Init ──────────────────────────────────────────────────────

.PHONY: init-aws init-azure init-vmware

init-aws: ## Download plugins for AWS template
	cd aws-webserver && packer init .

init-azure: ## Download plugins for Azure template
	cd azure-base && packer init .

init-vmware: ## Download plugins for VMware template
	cd vmware-base && packer init .

# ── Validate ──────────────────────────────────────────────────

.PHONY: validate-aws validate-azure validate-vmware validate-all

validate-aws: init-aws ## Validate AWS template
	cd aws-webserver && packer validate .

validate-azure: init-azure ## Validate Azure template (uses placeholder subscription_id)
	cd azure-base && packer validate -var "subscription_id=12345678-1234-1234-1234-123456789012" .

validate-vmware: init-vmware ## Validate VMware template (uses placeholder vCenter vars)
	cd vmware-base && packer validate \
		-var "vcenter_server=placeholder.local" \
		-var "vcenter_username=placeholder" \
		-var "vcenter_password=placeholder" \
		.

validate-all: validate-aws validate-azure validate-vmware ## Validate all templates

# ── Build ─────────────────────────────────────────────────────

.PHONY: build-aws build-azure build-vmware

build-aws: init-aws ## Build AWS AMI (requires AWS credentials)
	cd aws-webserver && packer build .

build-azure: init-azure ## Build Azure image (requires az login or SP credentials)
	cd azure-base && packer build .

build-vmware: init-vmware ## Build VMware template (requires vCenter credentials)
	cd vmware-base && packer build .

# ── Lint ──────────────────────────────────────────────────────

.PHONY: lint

lint: ## Run shellcheck on all shared scripts
	shellcheck shared/scripts/*.sh

# ── Format ────────────────────────────────────────────────────

.PHONY: fmt fmt-check

fmt: ## Auto-format all Packer HCL files
	packer fmt aws-webserver/
	packer fmt azure-base/
	packer fmt vmware-base/

fmt-check: ## Check Packer HCL formatting (no changes)
	packer fmt -check -diff aws-webserver/
	packer fmt -check -diff azure-base/
	packer fmt -check -diff vmware-base/

# ── Help ──────────────────────────────────────────────────────

.PHONY: help

help: ## Show this help message
	@echo "Packer Image Factory — available targets:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
