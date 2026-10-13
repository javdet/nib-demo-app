locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  name = var.project_name # "nib-demo-prod" - short for the many places it prefixes a resource name

  # --- the approved cost-optimized topology ---------------------------------
  # Two AZs for the ALB/application/database subnet tiers, but only one NAT
  # gateway (shared by both private application subnets) and a single-AZ
  # database: half the cost of the fully redundant version, acceptable for a
  # demo. Kept as locals, not variables, because they are a topology decision
  # rather than a per-environment input - there is only one environment.
  az_count              = length(var.availability_zones)
  single_nat_gateway    = true
  db_multi_az           = false
  backend_desired_count = 1 # the "eventual one task" - deploy-application.yml sets this after the first image push; Terraform starts the service at 0 and ignores drift (see ecs.tf)

  # --- subnetting -------------------------------------------------------------
  # /20s out of the /16: room for ~4k addresses per tier per AZ, far more than
  # this workload needs, but it keeps the math readable rather than tight.
  public_subnet_cidrs   = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  app_subnet_cidrs      = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 4, i + local.az_count)]
  database_subnet_cidrs = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 4, i + 2 * local.az_count)]

  # --- names referenced across files ------------------------------------------
  ecr_repository_name  = "${local.name}-backend"
  ecs_cluster_name     = local.name
  ecs_service_name     = "${local.name}-backend"
  rds_identifier       = "${local.name}-postgres"
  database_secret_name = "nib-demo/prod/database"
  frontend_bucket_name = "${local.name}-frontend-${local.account_id}"
  cf_logs_bucket_name  = "${local.name}-cf-logs-${local.account_id}"
  log_group_name       = "/ecs/${local.name}"
}
