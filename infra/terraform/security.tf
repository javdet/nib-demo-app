# Security groups for the three tiers, plus the ALB itself: a fixed 403
# default action and a listener rule that only forwards requests carrying a
# secret header CloudFront injects on its origin requests. The ALB DNS name
# is still publicly resolvable (CloudFront has to reach it over the
# internet), but nothing except CloudFront knows the header value, so hitting
# the ALB directly - or through any other CDN - gets a 403.

data "aws_ec2_managed_prefix_list" "cloudfront_origin_facing" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "random_password" "cloudfront_origin_header" {
  length  = 32
  special = false
}

locals {
  cloudfront_origin_header_name  = "X-Nib-Origin-Verify"
  cloudfront_origin_header_value = random_password.cloudfront_origin_header.result
}

# ------------------------------------------------------------------- ALB ----

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "ALB: inbound only from CloudFront's origin-facing IP ranges"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name}-alb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from CloudFront's managed origin-facing prefix list"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront_origin_facing.id
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To the ECS tasks it forwards to"
  ip_protocol                  = "tcp"
  from_port                    = var.backend_container_port
  to_port                      = var.backend_container_port
  referenced_security_group_id = aws_security_group.ecs_task.id
}

# -------------------------------------------------------------- ECS tasks --

resource "aws_security_group" "ecs_task" {
  name        = "${local.name}-ecs-task"
  description = "ECS tasks: inbound only from the ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name}-ecs-task"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs_task.id
  description                  = "Application port, from the ALB only"
  ip_protocol                  = "tcp"
  from_port                    = var.backend_container_port
  to_port                      = var.backend_container_port
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "ecs_all_outbound" {
  security_group_id = aws_security_group.ecs_task.id
  description       = "ECR, Secrets Manager, CloudWatch Logs (via NAT) and RDS"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# -------------------------------------------------------------------- RDS --

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds"
  description = "RDS: inbound only from the ECS tasks; no egress"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name}-rds"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id            = aws_security_group.rds.id
  description                  = "Postgres, from the ECS task security group only"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.ecs_task.id
}

# --------------------------------------------------------------------- ALB --
# Public subnets because CloudFront's origin fetch has to reach it over the
# internet; the security group above is what actually restricts who gets in.

resource "aws_lb" "main" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb.id]

  drop_invalid_header_fields = true

  tags = {
    Name = "${local.name}-alb"
  }
}

resource "aws_lb_target_group" "backend" {
  name        = "${local.name}-backend"
  port        = var.backend_container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = var.backend_health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${local.name}-backend"
  }
}

# Nothing reaches the target group unless it both cleared the security group
# (CloudFront's IP ranges) and presents the secret header - belt and braces
# against someone finding the ALB DNS name and pointing a browser at it.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      status_code  = "403"
      content_type = "text/plain"
      message_body = "Forbidden"
    }
  }
}

resource "aws_lb_listener_rule" "cloudfront_only" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    http_header {
      http_header_name = local.cloudfront_origin_header_name
      values           = [local.cloudfront_origin_header_value]
    }
  }
}
