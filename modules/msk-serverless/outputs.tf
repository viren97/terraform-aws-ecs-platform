output "cluster_arn" {
  value = aws_msk_serverless_cluster.this.arn
}

output "cluster_name" {
  value = aws_msk_serverless_cluster.this.cluster_name
}

output "bootstrap_brokers_sasl_iam" {
  value = data.aws_msk_bootstrap_brokers.this.bootstrap_brokers_sasl_iam
}

output "topic_arn_prefix" {
  description = "Append a topic name (or *) to scope kafka-cluster:*Topic permissions."
  value       = "${format(local.arn_base, "topic")}/"
}

output "group_arn_prefix" {
  description = "Append a consumer group name (or *) to scope kafka-cluster:*Group permissions."
  value       = "${format(local.arn_base, "group")}/"
}

output "transactional_id_arn_prefix" {
  value = "${format(local.arn_base, "transactional-id")}/"
}

output "security_group_id" {
  value = aws_security_group.this.id
}
