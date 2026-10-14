# Exactly these six: the application deploy job consumes them and nothing
# else. None of them are secret - the database connection string never
# leaves Secrets Manager via Terraform state output.

output "ecr_repository_url" {
  description = "Push target for the backend image."
  value       = aws_ecr_repository.backend.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster the backend service runs in."
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service the deploy job updates."
  value       = aws_ecs_service.backend.name
}

output "frontend_bucket_name" {
  description = "S3 bucket the frontend deploy job syncs dist/ into."
  value       = aws_s3_bucket.frontend.id
}

output "cloudfront_distribution_id" {
  description = "Distribution the deploy job invalidates after a frontend sync."
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_domain_name" {
  description = "Public hostname the deploy job smoke-tests against."
  value       = aws_cloudfront_distribution.main.domain_name
}
