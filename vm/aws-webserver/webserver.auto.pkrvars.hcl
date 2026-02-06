# ──────────────────────────────────────────────────────────────
# webserver.auto.pkrvars.hcl — Environment-specific overrides
# ──────────────────────────────────────────────────────────────
# Files ending in .auto.pkrvars.hcl are loaded automatically.
# Adjust these values for your AWS account / environment.
#
# ⚠ Do NOT commit secrets here. Use env vars instead:
#    export PKR_VAR_aws_region="us-east-1"
# ──────────────────────────────────────────────────────────────

aws_region      = "eu-west-1"
instance_type   = "t3.small"          # Bigger = faster builds
ami_name_prefix = "webserver"
environment     = "staging"
team            = "platform-engineering"
node_version    = "20"

# Copy the finished AMI to these additional regions
ami_regions = [
  "eu-central-1",
  "us-east-1",
]

# Share with these AWS account IDs (empty = private)
ami_users = []
