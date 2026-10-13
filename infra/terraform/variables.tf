variable "project_name" {
  type        = string
  description = "Name prefix for every resource this configuration creates."
  default     = "nib-demo-prod"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}$", var.project_name))
    error_message = "project_name must be lowercase alphanumeric with hyphens, starting with a letter."
  }
}

variable "aws_region" {
  type        = string
  description = "Region for every resource. CloudFront and the OIDC trust in infra/bootstrap are not region-scoped, but everything else here is."
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "This configuration is only exercised against us-east-1; the bootstrap stack, prefix lists and ARNs assume it."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR for the VPC. /16 leaves room for more subnet tiers later without resizing."
  default     = "10.42.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && split("/", var.vpc_cidr)[1] == "16"
    error_message = "vpc_cidr must be a valid /16 CIDR block."
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "Exactly two AZs - the cost-optimized topology trades multi-AZ resilience for one NAT gateway and a single-AZ database."
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "This topology is costed and sized for exactly two Availability Zones."
  }
}

variable "nat_gateway_count" {
  type        = number
  description = "Number of NAT gateways. Fixed at one: both private application subnets share it, which is the approved cost trade-off (no NAT-gateway-per-AZ redundancy)."
  default     = 1

  validation {
    condition     = var.nat_gateway_count == 1
    error_message = "The approved topology has exactly one NAT gateway."
  }
}

variable "backend_container_port" {
  type        = number
  description = "Port the FastAPI container listens on, per backend/Dockerfile."
  default     = 8000

  validation {
    condition     = var.backend_container_port > 0 && var.backend_container_port < 65536
    error_message = "backend_container_port must be a valid TCP port."
  }
}

variable "backend_health_check_path" {
  type        = string
  description = "ALB target group health check path. /api/health/ready touches the database; /api/health does not."
  default     = "/api/health/ready"
}

variable "backend_task_cpu" {
  type        = number
  description = "Fargate task vCPU units for the one eventual backend task."
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.backend_task_cpu)
    error_message = "backend_task_cpu must be a valid Fargate CPU value."
  }
}

variable "backend_task_memory" {
  type        = number
  description = "Fargate task memory (MiB), matched to backend_task_cpu's valid combinations."
  default     = 512

  validation {
    condition     = var.backend_task_memory >= 512 && var.backend_task_memory % 256 == 0
    error_message = "backend_task_memory must be a multiple of 256 MiB and at least 512."
  }
}

variable "backend_log_retention_days" {
  type        = number
  description = "CloudWatch Logs retention for the ECS log group."
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653, 0], var.backend_log_retention_days)
    error_message = "backend_log_retention_days must be a value CloudWatch Logs accepts."
  }
}

variable "db_engine_version" {
  type        = string
  description = "PostgreSQL major.minor version for RDS."
  default     = "17.11"
}

variable "db_instance_class" {
  type        = string
  description = "Single-AZ db.t4g.micro is the approved cost trade-off for a demo workload."
  default     = "db.t4g.micro"

  validation {
    condition     = can(regex("^db\\.", var.db_instance_class))
    error_message = "db_instance_class must be a valid RDS instance class (starts with \"db.\")."
  }
}

variable "db_allocated_storage_gb" {
  type        = number
  description = "GP3 storage for RDS, in GiB."
  default     = 20

  validation {
    condition     = var.db_allocated_storage_gb >= 20 && var.db_allocated_storage_gb <= 100
    error_message = "db_allocated_storage_gb must be between 20 and 100 for this workload."
  }
}

variable "db_name" {
  type        = string
  description = "Database name, matching backend/app/config.py's default DSN."
  default     = "nibshop"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.db_name))
    error_message = "db_name must be a valid PostgreSQL identifier."
  }
}

variable "db_username" {
  type        = string
  description = "Application database user. Not the RDS master user name by coincidence - there is no separate master account."
  default     = "nib_app"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.db_username))
    error_message = "db_username must be a valid PostgreSQL identifier."
  }
}

variable "db_backup_retention_days" {
  type        = number
  description = "Automated RDS backup retention."
  default     = 7

  validation {
    condition     = var.db_backup_retention_days >= 1 && var.db_backup_retention_days <= 35
    error_message = "db_backup_retention_days must be between 1 and 35."
  }
}

variable "db_backup_window" {
  type        = string
  description = "Daily UTC window for automated backups, before the maintenance window."
  default     = "03:00-03:30"
}

variable "db_maintenance_window" {
  type        = string
  description = "Weekly UTC window for automatic minor version upgrades."
  default     = "sun:04:00-sun:04:30"
}

variable "github_repository" {
  type        = string
  description = "GitHub repository in owner/name form, used only to label resources - the trust relationship itself lives in infra/bootstrap/template.yml."
  default     = "javdet/nib-demo-app"
}
