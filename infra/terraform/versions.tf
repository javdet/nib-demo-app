# Terraform and provider versions are pinned exactly; the lock file
# (.terraform.lock.hcl) records the matching checksums and is committed.
#
# The S3 backend is "partial": bucket/key/region are supplied at `terraform
# init` time by the deploy-infrastructure workflow (see infra/terraform/README.md),
# because the bucket name is derived from the AWS account id and this file
# cannot interpolate variables.
terraform {
  required_version = "= 1.10.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.100.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }

  backend "s3" {
    # bucket = "nib-demo-terraform-state-${AWS_ACCOUNT_ID}"
    # key    = "nib-demo/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
