# ──────────────────────────────────────────────────────────────
# base.auto.pkrvars.hcl — Azure environment overrides
# ──────────────────────────────────────────────────────────────

subscription_id   = "00000000-0000-0000-0000-000000000000" # ← Replace
location          = "westeurope"
resource_group    = "rg-packer-images"
vm_size           = "Standard_B2s"
image_name_prefix = "ubuntu-base"
environment       = "staging"
team              = "platform-engineering"

# Service Principal credentials — prefer env vars in CI:
#   export PKR_VAR_client_id="..."
#   export PKR_VAR_client_secret="..."
#   export PKR_VAR_tenant_id="..."
