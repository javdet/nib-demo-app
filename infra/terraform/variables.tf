variable "project_name" {
  description = "Short project slug used to build resource names."
  type        = string
  default     = "nib-demo-app"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "project_name must be lowercase alphanumeric with hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment. This configuration only models prod."
  type        = string
  default     = "prod"

  validation {
    condition     = var.environment == "prod"
    error_message = "environment must be \"prod\"; this configuration does not model other environments."
  }
}

variable "global_prefix" {
  description = "Account-specific prefix used for globally-unique resource names (S3 buckets)."
  type        = string
  default     = "javdet"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.global_prefix))
    error_message = "global_prefix must be lowercase alphanumeric with hyphens, starting with a letter."
  }
}

variable "aws_region" {
  description = "AWS region for every resource in this configuration."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must look like a region code, e.g. us-east-1."
  }
}

# ---------------------------------------------------------------- network --

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public ALB/NAT subnets, one per Availability Zone."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly two public subnet CIDRs are required, one per Availability Zone."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private ECS subnets, one per Availability Zone."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Exactly two private subnet CIDRs are required, one per Availability Zone."
  }
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for the isolated RDS subnets, one per Availability Zone."
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]

  validation {
    condition     = length(var.database_subnet_cidrs) == 2
    error_message = "Exactly two database subnet CIDRs are required, one per Availability Zone."
  }
}

# --------------------------------------------------------------- database --

# Major version only by default: RDS retires old minors (16.6 is gone), and
# with auto_minor_version_upgrade a pinned minor would have Terraform try to
# downgrade the instance after every AWS upgrade.
variable "db_engine_version" {
  description = "PostgreSQL engine version for RDS."
  type        = string
  default     = "16"

  validation {
    condition     = can(regex("^16(\\.[0-9]+)?$", var.db_engine_version))
    error_message = "db_engine_version must be PostgreSQL 16 (\"16\" or a 16.x minor version)."
  }
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"

  validation {
    condition     = can(regex("^db\\.", var.db_instance_class))
    error_message = "db_instance_class must be a valid RDS instance class, e.g. db.t4g.micro."
  }
}

variable "db_allocated_storage" {
  description = "Initial RDS storage, in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.db_allocated_storage >= 20
    error_message = "db_allocated_storage must be at least 20 GiB."
  }
}

variable "db_max_allocated_storage" {
  description = "Upper bound for RDS storage autoscaling, in GiB."
  type        = number
  default     = 100

  validation {
    condition     = var.db_max_allocated_storage >= 20
    error_message = "db_max_allocated_storage must be at least 20 GiB."
  }
}

variable "db_name" {
  description = "Name of the application database created on the RDS instance."
  type        = string
  default     = "nibshop"

  validation {
    condition     = can(regex("^[a-zA-Z_][a-zA-Z0-9_]*$", var.db_name))
    error_message = "db_name must be a valid PostgreSQL identifier."
  }
}

variable "db_username" {
  description = "Master username for the RDS instance. The password is generated and never stored in variables or state in plain text."
  type        = string
  default     = "nib_admin"

  validation {
    condition     = can(regex("^[a-zA-Z_][a-zA-Z0-9_]*$", var.db_username))
    error_message = "db_username must be a valid PostgreSQL identifier."
  }
}

variable "db_backup_retention_days" {
  description = "Number of days to retain automated RDS backups."
  type        = number
  default     = 7

  validation {
    condition     = var.db_backup_retention_days >= 7
    error_message = "db_backup_retention_days must be at least 7 days."
  }
}

# -------------------------------------------------------------------- ecs --

variable "container_port" {
  description = "Port the backend container listens on."
  type        = number
  default     = 8000

  validation {
    condition     = var.container_port > 0 && var.container_port < 65536
    error_message = "container_port must be a valid TCP port."
  }
}

variable "ecs_task_cpu" {
  description = "Fargate task-level vCPU units."
  type        = number
  default     = 512

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.ecs_task_cpu)
    error_message = "ecs_task_cpu must be a Fargate-supported CPU value."
  }
}

variable "ecs_task_memory" {
  description = "Fargate task-level memory, in MiB."
  type        = number
  default     = 1024

  validation {
    condition     = var.ecs_task_memory >= 512
    error_message = "ecs_task_memory must be at least 512 MiB."
  }
}

variable "ecs_min_capacity" {
  description = "Minimum ECS service task count once autoscaling is active."
  type        = number
  default     = 2

  validation {
    condition     = var.ecs_min_capacity >= 2
    error_message = "ecs_min_capacity must be at least 2; this service does not scale to zero during normal operation."
  }
}

variable "ecs_max_capacity" {
  description = "Maximum ECS service task count."
  type        = number
  default     = 6

  validation {
    condition     = var.ecs_max_capacity >= 2
    error_message = "ecs_max_capacity must be at least 2."
  }
}

# --------------------------------------------------------- load balancer --

variable "alb_health_check_path" {
  description = "Path the ALB target group uses for backend health checks."
  type        = string
  default     = "/api/health/ready"

  validation {
    condition     = can(regex("^/", var.alb_health_check_path))
    error_message = "alb_health_check_path must start with /."
  }
}

variable "alb_deregistration_delay" {
  description = "Seconds the ALB waits for in-flight requests to drain before deregistering a target."
  type        = number
  default     = 30

  validation {
    condition     = var.alb_deregistration_delay >= 0 && var.alb_deregistration_delay <= 3600
    error_message = "alb_deregistration_delay must be between 0 and 3600 seconds."
  }
}

# ------------------------------------------------------------ observability --

variable "log_retention_days" {
  description = "CloudWatch Logs retention, in days, for ECS and RDS log exports."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a value CloudWatch Logs accepts as a retention period."
  }
}

variable "enable_alarm_notifications" {
  description = "Whether to create an SNS topic for CloudWatch alarms. No subscription is created by this configuration; add one out of band once a real recipient exists."
  type        = bool
  default     = true
}
