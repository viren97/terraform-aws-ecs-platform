resource "aws_security_group" "this" {
  name_prefix = "${var.name}-msk-"
  description = "MSK Serverless for ${var.name}"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-msk" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "clients" {
  for_each                     = toset(var.allowed_security_group_ids)
  security_group_id            = aws_security_group.this.id
  description                  = "Kafka SASL/IAM over TLS"
  ip_protocol                  = "tcp"
  from_port                    = 9098
  to_port                      = 9098
  referenced_security_group_id = each.value
}

resource "aws_msk_serverless_cluster" "this" {
  cluster_name = var.name
  tags         = var.tags

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.this.id]
  }

  client_authentication {
    sasl {
      iam {
        enabled = true
      }
    }
  }
}

data "aws_msk_bootstrap_brokers" "this" {
  cluster_arn = aws_msk_serverless_cluster.this.arn
}

locals {
  # ARN prefixes used to scope client IAM policies to this cluster's topics and groups.
  arn_base = replace(aws_msk_serverless_cluster.this.arn, ":cluster/", ":%s/")
}
