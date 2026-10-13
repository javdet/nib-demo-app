terraform {
  required_version = "= 1.16.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.68.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # The concrete bucket, key, region and dynamodb_table are not hard-coded here:
  # infra/bootstrap/template.yml creates a state bucket and lock table whose
  # names are derived from the AWS account id, so deploy-infrastructure.yml
  # resolves them at `terraform init -backend-config=...` time instead. Local
  # development against this configuration needs the same flags; see the
  # README's "production bootstrap" section.
  backend "s3" {
    key     = "nib-demo-prod/terraform.tfstate"
    encrypt = true
  }
}
