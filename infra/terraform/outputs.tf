# deploy-application.yml reads every one of these from `terraform output
# -json` rather than hardcoding names, so this list is also that workflow's
# entire contract with this configuration.

output "web_bucket_name" {
  description = "S3 bucket the frontend build is synced into."
  value       = aws_s3_bucket.web.bucket
}

output "ecr_repository_url" {
  description = "ECR repository the backend image is pushed to."
  value       = aws_ecr_repository.api.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster running the API service."
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service updated on each backend deploy. Also the task definition family name."
  value       = aws_ecs_service.api.name
}

output "cloudfront_distribution_id" {
  description = "Distribution invalidated after every frontend deploy."
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_domain_name" {
  description = "Public hostname of the site; the smoke test runs against this."
  value       = aws_cloudfront_distribution.main.domain_name
}
