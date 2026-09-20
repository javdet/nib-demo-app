provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "nib-demo"
      Environment = "production"
      Prefix      = local.name_prefix
      ManagedBy   = "terraform"
    }
  }
}

# The account id feeds the state bucket name (see README.md) and the two
# S3/ECR bucket names that must be globally unique.
data "aws_caller_identity" "current" {}

# Exactly two AZs, spread across the public/private/isolated subnet tiers in
# network.tf, is the whole of the "resilient outbound access" contract.
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name_prefix        = var.resource_prefix
  account_id         = data.aws_caller_identity.current.account_id
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
}
