locals {
  # Two Availability Zones, deterministically ordered, used everywhere a
  # resource needs to be spread across both.
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  name_prefix = "${var.project_name}-${var.environment}" # nib-demo-app-prod

  names = {
    vpc                = "${local.name_prefix}-vpc"
    alb                = "${local.name_prefix}-alb"
    alb_sg             = "${local.name_prefix}-alb-sg"
    ecs_sg             = "${local.name_prefix}-ecs-sg"
    rds_sg             = "${local.name_prefix}-rds-sg"
    db_subnet_group    = "${local.name_prefix}-db-subnet-group"
    db_parameter_group = "${local.name_prefix}-pg16"
    db_instance        = "${local.name_prefix}-db"
    ecs_execution_role = "${local.name_prefix}-ecs-execution-role"
    ecs_task_role      = "${local.name_prefix}-ecs-task-role"
    ecs_task_family    = "${local.name_prefix}-backend"
    cloudfront_oac     = "${local.name_prefix}-frontend-oac"
    alarm_topic        = "${local.name_prefix}-alarms"

    # Contracted names: depended on by outputs.tf and the deploy workflow, so
    # these do not simply follow the "${name_prefix}-*" pattern above.
    ecr_repository  = "${var.project_name}-backend"                    # nib-demo-app-backend
    ecs_cluster     = local.name_prefix                                # nib-demo-app-prod
    ecs_service     = "${var.project_name}-backend-${var.environment}" # nib-demo-app-backend-prod
    frontend_bucket = "${var.global_prefix}-${var.project_name}-${var.environment}-frontend"
    tfstate_bucket  = "${var.global_prefix}-${var.project_name}-${var.environment}-tfstate"
    secret_name     = "${var.project_name}/${var.environment}/database"
    logs_bucket     = "${var.global_prefix}-${var.project_name}-${var.environment}-logs"
  }

  log_group_names = {
    ecs      = "/ecs/${local.name_prefix}-backend"
    ecs_exec = "/ecs/${local.name_prefix}-exec"
    rds      = "/aws/rds/instance/${local.names.db_instance}/postgresql"
  }
}
