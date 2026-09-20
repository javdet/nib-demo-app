# Generated once and stored only in Secrets Manager (see secrets.tf) - never
# an output, never logged, never referenced anywhere state could be printed.
resource "random_password" "db" {
  length  = 32
  special = false # kept out of the URI-encoding path entirely, not just encoded
}

resource "aws_db_parameter_group" "postgres16" {
  name   = "postgres16"
  family = "postgres16"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = {
    Name = "postgres16"
  }
}

resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-postgres"

  engine               = "postgres"
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class
  parameter_group_name = aws_db_parameter_group.postgres16.name

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 5432

  storage_type          = "gp3"
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_encrypted     = true

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  backup_retention_period    = var.db_backup_retention_period
  backup_window              = "04:00-04:30"
  maintenance_window         = "sun:05:00-sun:05:30"
  auto_minor_version_upgrade = true
  deletion_protection        = true
  copy_tags_to_snapshot      = true

  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.name_prefix}-postgres-final"

  tags = {
    Name = "${local.name_prefix}-postgres"
  }

  lifecycle {
    # The password is generated once; a later apply must not try to rotate it
    # out from under Secrets Manager or a running application.
    ignore_changes = [password]
  }
}
