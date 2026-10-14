resource "aws_db_subnet_group" "main" {
  name       = local.names.db_subnet_group
  subnet_ids = aws_subnet.database[*].id

  tags = {
    Name = local.names.db_subnet_group
  }
}

resource "aws_db_parameter_group" "postgres16" {
  name   = local.names.db_parameter_group
  family = "postgres16"

  tags = {
    Name = local.names.db_parameter_group
  }
}

# Generated once and never written to a variable or a .tf file; the only
# place it ends up is the Secrets Manager secret below and Terraform state,
# which the S3 backend already encrypts.
resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?"
}

resource "aws_db_instance" "main" {
  identifier = local.names.db_instance

  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.postgres16.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az                   = true
  auto_minor_version_upgrade = true

  backup_retention_period   = var.db_backup_retention_days
  copy_tags_to_snapshot     = true
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.names.db_instance}-final"

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  apply_immediately = false

  tags = {
    Name = local.names.db_instance
  }
}

# The complete async SQLAlchemy DSN the backend reads as DATABASE_URL. Built
# here, not in a variable, so the password never has a path through plan
# output other than this already-sensitive expression.
locals {
  database_url = "postgresql+asyncpg://${var.db_username}:${urlencode(random_password.db.result)}@${aws_db_instance.main.address}:${aws_db_instance.main.port}/${var.db_name}"
}

resource "aws_secretsmanager_secret" "database" {
  name        = local.names.secret_name
  description = "Async SQLAlchemy DATABASE_URL for ${local.name_prefix}, injected into the ECS task as a secret."

  tags = {
    Name = local.names.secret_name
  }
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    DATABASE_URL = local.database_url
  })
}
