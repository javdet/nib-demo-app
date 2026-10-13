# Exactly what deploy-application.yml needs to build, push, sync and smoke
# test - read from state rather than re-derived, so the workflow can never
# drift from what Terraform actually created. Nothing here is secret; the
# database connection and the CloudFront origin header live only in Secrets
# Manager and in Terraform's own resource graph; database_secret_arn is the
# one exception, and even an ARN (not a credential) is kept sensitive so it
# never ends up in a job summary by accident.

output "app_url" {
  description = "Public URL of the store - the CloudFront distribution, and the only origin a browser ever talks to."
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "Distribution id, for the post-deploy invalidation."
  value       = aws_cloudfront_distribution.main.id
}

output "frontend_bucket_name" {
  description = "Private bucket the built SPA is synced into."
  value       = aws_s3_bucket.frontend.id
}

output "ecr_repository_url" {
  description = "Repository the backend image is built and pushed to."
  value       = aws_ecr_repository.backend.repository_url
}

output "ecs_cluster_name" {
  description = "Cluster the backend service runs in."
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Service deploy-application.yml updates after registering a new task-definition revision."
  value       = aws_ecs_service.backend.name
}

output "ecs_task_definition_family" {
  description = "Family deploy-application.yml registers each new revision under."
  value       = aws_ecs_task_definition.backend.family
}

output "database_secret_arn" {
  description = "Secrets Manager secret the task definition injects DATABASE_URL from. Not a credential by itself, but kept sensitive so it never appears in a workflow log line that could be mistaken for one."
  value       = aws_secretsmanager_secret.database.arn
  sensitive   = true
}
