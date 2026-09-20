# Every variable below has a working default; this is a single-environment
# ("production") demo stack, not a module meant to be re-parameterized per
# environment. The defaults ARE the contract the rest of the configuration
# and the GitHub workflows are written against - see README.md.

variable "aws_region" {
  description = "AWS region for every resource. The Terraform state bucket and CloudFront's origin-facing prefix list are also region-specific, so this is effectively fixed."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "The state backend, database subnet group and CloudFront prefix list in this configuration are all wired to us-east-1."
  }
}

variable "environment" {
  description = "Deployment environment name, used in tags and default_tags."
  type        = string
  default     = "production"

  validation {
    condition     = var.environment == "production"
    error_message = "This configuration only models a single, production environment."
  }
}

variable "resource_prefix" {
  description = "Prefix applied to every named resource (nib-demo-prod-vpc, nib-demo-prod-alb, ...)."
  type        = string
  default     = "nib-demo-prod"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,32}[a-z0-9]$", var.resource_prefix))
    error_message = "resource_prefix must be lowercase alphanumeric with hyphens (it is used verbatim in S3 bucket and ECR repository names)."
  }
}

# --- network ----------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidrs" {
  description = "Two public subnet CIDRs (ALB + NAT gateways), one per Availability Zone."
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2 && alltrue([for c in var.public_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "public_subnet_cidrs must contain exactly two valid CIDR blocks, one per Availability Zone."
  }
}

variable "private_subnet_cidrs" {
  description = "Two private subnet CIDRs (ECS tasks), one per Availability Zone."
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 2 && alltrue([for c in var.private_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "private_subnet_cidrs must contain exactly two valid CIDR blocks, one per Availability Zone."
  }
}

variable "database_subnet_cidrs" {
  description = "Two isolated subnet CIDRs (RDS), one per Availability Zone. No route to the internet."
  type        = list(string)
  default     = ["10.20.20.0/24", "10.20.21.0/24"]

  validation {
    condition     = length(var.database_subnet_cidrs) == 2 && alltrue([for c in var.database_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "database_subnet_cidrs must contain exactly two valid CIDR blocks, one per Availability Zone."
  }
}

# --- ecs ----------------------------------------------------------------

variable "ecs_task_cpu" {
  description = "Fargate task vCPU units."
  type        = number
  default     = 512

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.ecs_task_cpu)
    error_message = "ecs_task_cpu must be a value Fargate accepts: 256, 512, 1024, 2048 or 4096."
  }
}

variable "ecs_task_memory" {
  description = "Fargate task memory, in MiB."
  type        = number
  default     = 1024

  validation {
    condition     = var.ecs_task_memory >= 512 && var.ecs_task_memory % 512 == 0
    error_message = "ecs_task_memory must be a multiple of 512 MiB."
  }
}

variable "ecs_desired_count" {
  description = "Steady-state task count once deploy-application has published a real image. The service is created at 0 and Terraform ignores drift on this field afterwards (see ecs.tf)."
  type        = number
  default     = 2

  validation {
    condition     = var.ecs_desired_count >= 1
    error_message = "ecs_desired_count must be at least 1."
  }
}

# --- database ----------------------------------------------------------------

variable "db_engine_version" {
  description = "PostgreSQL major version. The application's async driver and Alembic migrations are written and tested against this major version only."
  type        = string
  default     = "16"

  validation {
    condition     = var.db_engine_version == "16"
    error_message = "The parameter group, models and migrations in this repository are all written against PostgreSQL 16."
  }
}

variable "db_name" {
  description = "Database name. Must match backend/app/config.py's default DATABASE_URL and the seed data expectations."
  type        = string
  default     = "nibshop"

  validation {
    condition     = var.db_name == "nibshop"
    error_message = "The application connects to a database named nibshop; this is not independently configurable."
  }
}

variable "db_username" {
  description = "Master application username. Must match the DSN the application is built against."
  type        = string
  default     = "nibapp"

  validation {
    condition     = var.db_username == "nibapp"
    error_message = "The application connects as nibapp; this is not independently configurable."
  }
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"

  validation {
    condition     = can(regex("^db\\.[a-z0-9]+\\.[a-z0-9]+$", var.db_instance_class))
    error_message = "db_instance_class must look like an RDS instance class, e.g. db.t4g.micro."
  }
}

variable "db_allocated_storage" {
  description = "Initial RDS storage, in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.db_allocated_storage >= 20
    error_message = "db_allocated_storage must be at least 20 GiB (the GP3 minimum for RDS Postgres)."
  }
}

variable "db_max_allocated_storage" {
  description = "Ceiling for RDS storage autoscaling, in GiB."
  type        = number
  default     = 100

  validation {
    condition     = var.db_max_allocated_storage >= var.db_allocated_storage
    error_message = "db_max_allocated_storage must be greater than or equal to db_allocated_storage."
  }
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated RDS backups."
  type        = number
  default     = 7

  validation {
    condition     = var.db_backup_retention_period >= 1 && var.db_backup_retention_period <= 35
    error_message = "db_backup_retention_period must be between 1 and 35 days."
  }
}
