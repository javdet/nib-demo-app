# Cluster, roles, log group and a task definition/service pair that starts
# at desired_count = 0: there is no image in ECR until deploy-application.yml
# builds and pushes one. That workflow registers the real task definition
# revision (real image tag, real APP_VERSION/GIT_SHA) and raises desired_count
# to 1 itself; Terraform's job is to own everything around that and then get
# out of the way, which is what the two ignore_changes entries below do.

resource "aws_ecs_cluster" "main" {
  name = local.ecs_cluster_name

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name = local.ecs_cluster_name
  }
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = local.log_group_name
  retention_in_days = var.backend_log_retention_days

  tags = {
    Name = local.log_group_name
  }
}

# --------------------------------------------------------------------- IAM --

data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Pulls the image and writes logs; the only thing beyond the AWS managed
# policy it needs is permission to read the one database secret, which is
# how the secret in database.tf reaches the container without ever being a
# plain environment variable.
resource "aws_iam_role" "ecs_execution" {
  name               = "${local.name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_execution_secrets" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.database.arn]
  }
}

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name   = "read-database-secret"
  role   = aws_iam_role.ecs_execution.id
  policy = data.aws_iam_policy_document.ecs_execution_secrets.json
}

# The application itself calls no AWS API, so the task role gets nothing
# beyond the ability to exist and be assumed.
resource "aws_iam_role" "ecs_task" {
  name               = "${local.name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

# ---------------------------------------------------------- task definition --

resource "aws_ecs_task_definition" "backend" {
  family                   = local.ecs_service_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.backend_task_cpu)
  memory                   = tostring(var.backend_task_memory)
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  # Placeholder container: this revision never actually runs (desired_count
  # is 0 below), it just gives the service something valid to reference
  # until deploy-application.yml registers the first real revision.
  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${aws_ecr_repository.backend.repository_url}:bootstrap"
      essential = true

      portMappings = [
        {
          containerPort = var.backend_container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "ENVIRONMENT", value = "production" },
        { name = "AWS_REGION", value = local.region },
        { name = "APP_VERSION", value = "bootstrap" },
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
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = local.ecs_service_name
  }
}

# ------------------------------------------------------------------- service --

resource "aws_ecs_service" "backend" {
  name            = local.ecs_service_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  launch_type     = "FARGATE"
  desired_count   = 0

  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = aws_subnet.app[*].id
    security_groups  = [aws_security_group.ecs_task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = var.backend_container_port
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener_rule.cloudfront_only,
    aws_iam_role_policy_attachment.ecs_execution_managed,
    aws_iam_role_policy.ecs_execution_secrets,
  ]

  lifecycle {
    # deploy-application.yml owns both of these after the first image push:
    # it registers new task-definition revisions directly and raises
    # desired_count to the contracted one task. Without this, the next
    # `terraform apply` would fight it and scale back to 0.
    ignore_changes = [desired_count, task_definition]
  }

  tags = {
    Name = local.ecs_service_name
  }
}
