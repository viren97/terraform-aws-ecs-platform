output "address" {
  value = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "jdbc_url" {
  description = "JDBC URL with TLS required."
  value       = "jdbc:postgresql://${aws_db_instance.this.address}:${aws_db_instance.this.port}/${var.database_name}?sslmode=require"
}

output "username" {
  value = var.username
}

output "master_user_secret_arn" {
  description = "Secrets Manager secret holding {username, password}, rotated by RDS."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "security_group_id" {
  value = aws_security_group.this.id
}

output "instance_id" {
  value = aws_db_instance.this.identifier
}
