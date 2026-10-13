# The only tfvars file in this configuration - there is exactly one
# environment. Values are spelled out explicitly, even where they match a
# variable's default, so a reviewer can see the whole shape of production in
# one file instead of cross-referencing variables.tf.

project_name = "nib-demo-prod"
aws_region   = "us-east-1"

vpc_cidr           = "10.42.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
nat_gateway_count  = 1

backend_container_port     = 8000
backend_health_check_path  = "/api/health/ready"
backend_task_cpu           = 256
backend_task_memory        = 512
backend_log_retention_days = 30

db_engine_version        = "17.11"
db_instance_class        = "db.t4g.micro"
db_allocated_storage_gb  = 20
db_name                  = "nibshop"
db_username              = "nib_app"
db_backup_retention_days = 7
db_backup_window         = "03:00-03:30"
db_maintenance_window    = "sun:04:00-sun:04:30"

github_repository = "javdet/nib-demo-app"
