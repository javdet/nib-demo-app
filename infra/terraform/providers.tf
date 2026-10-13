provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Application = "nib-demo-app"
      Environment = "production"
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
