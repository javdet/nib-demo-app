# Logical contract: aws-secretsmanager:nib-demo/prod/database
# Real secret name: nib-demo/prod/database (see README.md for the mapping).
resource "aws_secretsmanager_secret" "database" {
  name        = "nib-demo/prod/database"
  description = "nib-demo production Postgres connection - contract URI aws-secretsmanager:nib-demo/prod/database"

  # Recovery window, not immediate deletion: a `terraform destroy` (or a
  # mistaken `terraform apply` that replaces this resource) leaves the secret
  # recoverable for the default 30 days instead of purging it outright.
  recovery_window_in_days = 30

  tags = {
    Name = "nib-demo-prod-database"
  }
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id

  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
    username = aws_db_instance.main.username
    password = random_password.db.result

    # The application reads this one key as a task-definition secret; the
    # fields above exist for anything that wants to compose its own DSN.
    DATABASE_URL = "postgresql+asyncpg://${urlencode(aws_db_instance.main.username)}:${urlencode(random_password.db.result)}@${aws_db_instance.main.address}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}"
  })
}

# Resource policy granting the ECS execution role read access. This is
# additive only (no explicit Deny): the account's own IAM principals -
# including whatever role runs `terraform apply` - keep whatever access their
# identity policies already grant them, so this cannot lock Terraform itself
# out of managing the secret.
resource "aws_secretsmanager_secret_policy" "database" {
  secret_arn = aws_secretsmanager_secret.database.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEcsExecutionRoleRead"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.ecs_execution.arn }
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = "*"
      }
    ]
  })
}
