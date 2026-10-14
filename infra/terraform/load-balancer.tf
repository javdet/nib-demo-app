# Public so CloudFront can reach it, but the ALB security group only
# accepts traffic from CloudFront's own address ranges, so nothing else on
# the internet can hit it directly.

resource "aws_lb" "main" {
  name               = local.names.alb
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = true

  access_logs {
    bucket  = aws_s3_bucket.logs.id
    prefix  = "alb"
    enabled = true
  }

  depends_on = [aws_s3_bucket_policy.logs]

  tags = {
    Name = local.names.alb
  }
}

resource "aws_lb_target_group" "backend" {
  name        = "${local.name_prefix}-backend-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  # Startup runs `alembic upgrade head` before the process starts listening,
  # and ECS deployments replace tasks one at a time; a generous deregistration
  # delay and a tolerant health check keep both from flapping the target
  # group during a deploy.
  deregistration_delay = var.alb_deregistration_delay

  health_check {
    path                = var.alb_health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${local.name_prefix}-backend-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
