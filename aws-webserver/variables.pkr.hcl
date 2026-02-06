# ──────────────────────────────────────────────────────────────
# variables.pkr.hcl — Input variables for the AWS webserver AMI
# ──────────────────────────────────────────────────────────────

# ── Region & Networking ──────────────────────────────────────

variable "aws_region" {
  type        = string
  default     = "eu-west-1"
  description = "AWS region where the temporary build instance runs."
}

variable "vpc_id" {
  type        = string
  default     = ""
  description = "VPC to launch the build instance in. Leave empty for the default VPC."
}

variable "subnet_id" {
  type        = string
  default     = ""
  description = "Subnet for the build instance. Leave empty for auto-selection."
}

# ── Instance Configuration ───────────────────────────────────

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type used during the build. Larger = faster builds."
}

variable "ssh_username" {
  type        = string
  default     = "ubuntu"
  description = "SSH user for the base AMI (ubuntu for Ubuntu, ec2-user for AL2)."
}

# ── AMI Settings ─────────────────────────────────────────────

variable "ami_name_prefix" {
  type        = string
  default     = "webserver"
  description = "Prefix for the output AMI name. Timestamp is appended automatically."
}

variable "ami_description" {
  type        = string
  default     = "Nginx + Node.js golden image built by Packer"
  description = "Human-readable description embedded in the AMI metadata."
}

variable "ami_regions" {
  type        = list(string)
  default     = []
  description = "Additional regions to copy the AMI to after build. Empty = build region only."
}

variable "ami_users" {
  type        = list(string)
  default     = []
  description = "AWS account IDs to share the AMI with. Empty = private to builder account."
}

# ── Application ──────────────────────────────────────────────

variable "node_version" {
  type        = string
  default     = "20"
  description = "Major version of Node.js LTS to install (via NodeSource)."
}

variable "nginx_config_path" {
  type        = string
  default     = ""
  description = "Optional path to a custom nginx.conf to upload. Empty = default config."
}

# ── Tags ─────────────────────────────────────────────────────

variable "environment" {
  type        = string
  default     = "production"
  description = "Target environment tag (production, staging, development)."

  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "environment must be production, staging, or development."
  }
}

variable "team" {
  type        = string
  default     = "platform"
  description = "Team responsible for this image."
}
