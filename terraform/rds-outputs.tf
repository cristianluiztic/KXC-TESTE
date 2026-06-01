output "rds_endpoint" {
  description = "Endpoint do RDS"
  value       = aws_db_instance.main.endpoint
}

output "rds_address" {
  description = "Endereço do RDS"
  value       = aws_db_instance.main.address
}

output "rds_database_name" {
  description = "Nome do banco de dados"
  value       = aws_db_instance.main.db_name
}

output "rds_port" {
  description = "Porta do RDS"
  value       = aws_db_instance.main.port
}

output "db_secret_arn" {
  description = "ARN do secret do banco de dados"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "ecr_repository_url" {
  description = "URL do repositório ECR"
  value       = aws_ecr_repository.main.repository_url
}

output "ecr_repository_name" {
  description = "Nome do repositório ECR"
  value       = aws_ecr_repository.main.name
}

output "cloudfront_domain_name" {
  description = "Domain name do CloudFront"
  value       = try(aws_cloudfront_distribution.main[0].domain_name, null)
}

output "autoscaling_target_id" {
  description = "Target ID para auto scaling"
  value       = aws_appautoscaling_target.ecs_target.resource_id
}
