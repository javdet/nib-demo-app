# Base security groups carry no inline rules: ALB and ECS reference each
# other's security group id, and ECS and RDS do the same, so inline
# ingress/egress blocks on both sides of either pair would make the two
# resources mutually dependent and Terraform would refuse to plan a cycle.
# Every rule below is therefore its own resource.

resource "aws_security_group" "alb" {
  name        = local.names.alb_sg
  description = "Public ALB - reachable only from CloudFront"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = local.names.alb_sg
  }
}

resource "aws_security_group" "ecs" {
  name        = local.names.ecs_sg
  description = "ECS backend tasks - reachable only from the ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = local.names.ecs_sg
  }
}

resource "aws_security_group" "rds" {
  name        = local.names.rds_sg
  description = "RDS PostgreSQL - reachable only from the ECS tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = local.names.rds_sg
  }
}

# ------------------------------------------------------------------- alb ---

resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from CloudFront origin-facing addresses only"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront_origin_facing.id
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward to backend tasks"
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = aws_security_group.ecs.id
}

# ------------------------------------------------------------------- ecs ---

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "Application traffic from the ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_rds" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "PostgreSQL for application queries and migrations"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.rds.id
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_https" {
  security_group_id = aws_security_group.ecs.id
  description       = "ECR image pulls, Secrets Manager, CloudWatch Logs and other AWS API calls over HTTPS"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# ------------------------------------------------------------------- rds ---

resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL from the backend tasks only"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.ecs.id
}
