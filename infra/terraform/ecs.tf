resource "aws_ecs_cluster" "main" {
  name = local.names.ecs_cluster

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.ecs_exec.name
      }
    }
  }

  tags = {
    Name = local.names.ecs_cluster
  }
}

# ------------------------------------------------------------------- iam ---

data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = local.names.ecs_execution_role
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name = local.names.ecs_execution_role
  }
}

# ECR pulls and CloudWatch Logs delivery for the container's own stdout/stderr.
resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# The managed policy above does not cover Secrets Manager: the execution role
# needs this to resolve the DATABASE_URL secret into a task-definition secret
# at container start.
data "aws_iam_policy_document" "ecs_execution_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.database.arn]
  }
}

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name   = "${local.names.ecs_execution_role}-secrets"
  role   = aws_iam_role.ecs_execution.id
  policy = data.aws_iam_policy_document.ecs_execution_secrets.json
}

resource "aws_iam_role" "ecs_task" {
  name               = local.names.ecs_task_role
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name = local.names.ecs_task_role
  }
}

# The application itself calls no AWS APIs; the task role exists only so
# ECS Exec has a channel to open and somewhere to log the session.
data "aws_iam_policy_document" "ecs_exec" {
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.ecs_exec.arn}:*"]
  }
}

resource "aws_iam_role_policy" "ecs_exec" {
  name   = "${local.names.ecs_task_role}-exec"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_exec.json
}

# ------------------------------------------------------------- task def ---

resource "aws_ecs_task_definition" "backend" {
  family                   = local.names.ecs_task_family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name = "backend"
      # Registered once so the service and target group have something to
      # point at before any image exists; the application deploy job
      # registers the revision that actually runs, and the service ignores
      # task_definition changes so Terraform never fights it.
      image     = "${aws_ecr_repository.backend.repository_url}:bootstrap"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "ENVIRONMENT", value = "prod" },
        { name = "AWS_REGION", value = var.aws_region },
        { name = "APP_VERSION", value = "0.0.0" },
        { name = "GIT_SHA", value = "bootstrap" },
      ]

      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = "${aws_secretsmanager_secret.database.arn}:DATABASE_URL::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "backend"
        }
      }
    }
  ])

  tags = {
    Name = local.names.ecs_task_family
  }
}

resource "aws_ecs_service" "backend" {
  name    = local.names.ecs_service
  cluster = aws_ecs_cluster.main.id

  # The application deploy job owns both of these once an image exists:
  # it registers new task-definition revisions and scales the service up.
  # Infrastructure only needs to exist; it does not need to run anything yet.
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 0

  launch_type                       = "FARGATE"
  platform_version                  = "LATEST"
  health_check_grace_period_seconds = 60
  enable_execute_command            = true

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name = local.names.ecs_service
  }
}
