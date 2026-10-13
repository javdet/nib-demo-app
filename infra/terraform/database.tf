# Single-AZ db.t4g.micro in the isolated database subnets, reachable only
# from the ECS task security group. The password is generated here, never
# typed anywhere, and lands only in the Secrets Manager secret the task
# definition injects at runtime (see ecs.tf) - it is never a plan/apply log
# line or a workflow output.

resource "aws_db_subnet_group" "main" {
  name       = local.rds_identifier
  subnet_ids = aws_subnet.database[*].id

  tags = {
    Name = local.rds_identifier
  }
}

resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "-_."
}

resource "aws_db_instance" "main" {
  identifier = local.rds_identifier

  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage_gb
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = local.db_multi_az

  auto_minor_version_upgrade = true
  maintenance_window         = var.db_maintenance_window
  backup_window              = var.db_backup_window
  backup_retention_period    = var.db_backup_retention_days
  copy_tags_to_snapshot      = true

  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.rds_identifier}-final"

  tags = {
    Name = local.rds_identifier
  }

  lifecycle {
    # The generated password is set once; later applies must not try to
    # "fix" it back from whatever's in Secrets Manager (there is no read
    # path back into random_password) or rotate it on every unrelated plan.
    ignore_changes = [password]
  }
}

resource "aws_secretsmanager_secret" "database" {
  name        = local.database_secret_name
  description = "Nib & Slate production database connection - consumed by ecs.tf as a task-definition secret, never a plain environment variable."

  tags = {
    Name = local.database_secret_name
  }
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id

  secret_string = jsonencode({
    DATABASE_URL = "postgresql+asyncpg://${var.db_username}:${urlencode(random_password.db.result)}@${aws_db_instance.main.address}:${aws_db_instance.main.port}/${var.db_name}"
    host         = aws_db_instance.main.address
    port         = aws_db_instance.main.port
    dbname       = var.db_name
    username     = var.db_username
    password     = random_password.db.result
  })
}
