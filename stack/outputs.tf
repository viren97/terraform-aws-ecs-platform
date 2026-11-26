output "alb_dns_name" {
  description = "Point *.<domain_name> (CNAME or Route 53 alias) here."
  value       = module.alb.dns_name
}

output "service_urls" {
  value = { for k, v in var.services : k => "https://${v.subdomain}.${var.domain_name}" }
}

output "ecr_repositories" {
  value = { for k, m in module.ecr : k => m.repository_url }
}

output "pipelines" {
  value = { for k, m in module.pipeline : k => m.pipeline_name }
}

output "app_secret_ids" {
  description = "Set these values once with `aws secretsmanager put-secret-value`."
  value       = { for k, s in aws_secretsmanager_secret.app : k => s.arn }
}

output "kafka_bootstrap_brokers" {
  value = module.kafka.bootstrap_brokers_sasl_iam
}
