output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr_block" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "App tier: ECS tasks and MSK."
  value       = aws_subnet.private[*].id
}

output "data_subnet_ids" {
  description = "Isolated tier: RDS and ElastiCache, no internet route."
  value       = aws_subnet.data[*].id
}
