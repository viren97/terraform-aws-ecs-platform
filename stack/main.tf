locals {
  name = "${var.project}-${var.environment}"
  prod = var.environment == "prod"
}

data "aws_caller_identity" "current" {}

# ================================================================ shared platform
resource "aws_kms_key" "platform" {
  description             = "${local.name}: logs, secrets, buckets, images"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "platform" {
  name          = "alias/${local.name}"
  target_key_id = aws_kms_key.platform.key_id
}

# CloudWatch Logs needs explicit permission to use the CMK.
data "aws_iam_policy_document" "kms" {
  statement {
    sid       = "AccountAdmin"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid       = "CloudWatchLogs"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }
  }
}

resource "aws_kms_key_policy" "platform" {
  key_id = aws_kms_key.platform.id
  policy = data.aws_iam_policy_document.kms.json
}

# Not encrypted with aws/sns on purpose: CloudWatch alarms cannot publish to topics using the AWS-managed key.
resource "aws_sns_topic" "alerts" {
  name = "${local.name}-alerts"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  count     = var.alarm_email == null ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

module "network" {
  source = "../modules/network"

  name               = local.name
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway
}

module "alb" {
  source = "../modules/alb"

  name                = local.name
  vpc_id              = module.network.vpc_id
  vpc_cidr_block      = module.network.vpc_cidr_block
  public_subnet_ids   = module.network.public_subnet_ids
  certificate_arn     = var.certificate_arn
  test_listener_cidrs = var.test_listener_cidrs
  deletion_protection = var.deletion_protection
}

module "cluster" {
  source = "../modules/ecs-cluster"

  name = local.name
}

module "artifacts" {
  source = "../modules/s3-bucket"

  name            = "${local.name}-artifacts-${data.aws_caller_identity.current.account_id}"
  kms_key_arn     = aws_kms_key.platform.arn
  expiration_days = 30
  force_destroy   = !var.deletion_protection
}

# Task security groups are created here (not inside ecs-service) so the data stores
# can allow them without a dependency cycle.
resource "aws_security_group" "service" {
  for_each = var.services

  name_prefix = "${local.name}-${each.key}-"
  description = "Tasks of ${each.key}"
  vpc_id      = module.network.vpc_id
  tags        = { Name = "${local.name}-${each.key}" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "service_from_alb" {
  for_each = var.services

  security_group_id            = aws_security_group.service[each.key].id
  description                  = "App port from the ALB only"
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = module.alb.security_group_id
}

resource "aws_vpc_security_group_egress_rule" "service_all" {
  for_each = var.services

  security_group_id = aws_security_group.service[each.key].id
  description       = "Outbound (data stores, AWS APIs, third-party APIs via NAT)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ================================================================ shared data plane
module "redis" {
  source = "../modules/elasticache-redis"

  name                       = local.name
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.data_subnet_ids
  allowed_security_group_ids = [for sg in aws_security_group.service : sg.id]
  node_type                  = var.redis.node_type
  replicas                   = var.redis.replicas
  kms_key_arn                = aws_kms_key.platform.arn
}

module "kafka" {
  source = "../modules/msk-serverless"

  name                       = local.name
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.private_subnet_ids
  allowed_security_group_ids = [for sg in aws_security_group.service : sg.id]
}

# ================================================================ per-service resources
# Database per service: no service can read another's tables.
module "db" {
  source   = "../modules/rds-postgres"
  for_each = var.services

  name                       = "${local.name}-${each.key}"
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.data_subnet_ids
  allowed_security_group_ids = [aws_security_group.service[each.key].id]
  database_name              = each.value.database.name
  username                   = each.value.database.username
  instance_class             = each.value.database.instance_class
  multi_az                   = each.value.database.multi_az
  deletion_protection        = var.deletion_protection
  enhanced_monitoring        = local.prod
  kms_key_arn                = aws_kms_key.platform.arn
}

module "app_bucket" {
  source   = "../modules/s3-bucket"
  for_each = { for k, v in var.services : k => v if v.app_bucket }

  name          = "${local.name}-${each.key}-${data.aws_caller_identity.current.account_id}"
  kms_key_arn   = aws_kms_key.platform.arn
  force_destroy = !var.deletion_protection
}

module "ecr" {
  source   = "../modules/ecr"
  for_each = var.services

  name         = "${var.project}/${each.key}"
  kms_key_arn  = aws_kms_key.platform.arn
  force_delete = !var.deletion_protection
}

# Third-party secrets (webhook HMAC keys, API keys). Terraform creates the container only;
# values are set out of band so they never land in state:
#   aws secretsmanager put-secret-value --secret-id <arn> --secret-string '...'
locals {
  app_secrets = merge([
    for svc, cfg in var.services : {
      for s in cfg.app_secrets : "${svc}/${s}" => { service = svc, env = s }
    }
  ]...)
}

resource "aws_secretsmanager_secret" "app" {
  for_each = local.app_secrets

  name        = "${local.name}/${each.key}"
  description = "${each.value.env} for ${each.value.service}"
  kms_key_id  = aws_kms_key.platform.arn
}

data "aws_iam_policy_document" "task" {
  for_each = var.services

  statement {
    sid       = "KafkaConnect"
    actions   = ["kafka-cluster:Connect", "kafka-cluster:DescribeCluster"]
    resources = [module.kafka.cluster_arn]
  }

  statement {
    sid = "KafkaTopics"
    actions = [
      "kafka-cluster:CreateTopic",
      "kafka-cluster:DescribeTopic",
      "kafka-cluster:DescribeTopicDynamicConfiguration",
      "kafka-cluster:ReadData",
      "kafka-cluster:WriteData",
    ]
    resources = [for t in each.value.kafka.topic_patterns : "${module.kafka.topic_arn_prefix}${t}"]
  }

  statement {
    sid       = "KafkaGroups"
    actions   = ["kafka-cluster:AlterGroup", "kafka-cluster:DescribeGroup"]
    resources = [for g in each.value.kafka.group_patterns : "${module.kafka.group_arn_prefix}${g}"]
  }

  statement {
    sid       = "KafkaIdempotentProducer"
    actions   = ["kafka-cluster:WriteDataIdempotently"]
    resources = [module.kafka.cluster_arn]
  }

  dynamic "statement" {
    for_each = each.value.app_bucket ? [1] : []
    content {
      sid       = "AppBucket"
      actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      resources = [module.app_bucket[each.key].arn, "${module.app_bucket[each.key].arn}/*"]
    }
  }

  dynamic "statement" {
    for_each = each.value.app_bucket ? [1] : []
    content {
      sid       = "AppBucketKms"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
      resources = [aws_kms_key.platform.arn]
    }
  }
}

module "service" {
  source   = "../modules/ecs-service"
  for_each = var.services

  name       = each.key
  short_name = each.value.short_name

  cluster_name       = module.cluster.name
  cluster_arn        = module.cluster.arn
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.private_subnet_ids
  security_group_ids = [aws_security_group.service[each.key].id]

  # Bootstrap image; the pipeline replaces it on the first release.
  image     = "${module.ecr[each.key].repository_url}:bootstrap"
  cpu       = each.value.cpu
  memory    = each.value.memory
  min_count = each.value.min_count
  max_count = each.value.max_count

  environment = merge(
    {
      SPRING_PROFILES_ACTIVE = "docker"
      JAVA_OPTS              = "-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError"

      DB_URL       = module.db[each.key].jdbc_url
      DB_USERNAME  = module.db[each.key].username
      DB_POOL_SIZE = "20"

      REDIS_HOST                     = module.redis.primary_endpoint
      REDIS_PORT                     = tostring(module.redis.port)
      SPRING_DATA_REDIS_SSL_ENABLED  = "true"

      # MSK Serverless only speaks SASL/IAM over TLS (needs software.amazon.msk:aws-msk-iam-auth on the classpath).
      KAFKA_BOOTSTRAP_SERVERS                              = module.kafka.bootstrap_brokers_sasl_iam
      SPRING_KAFKA_SECURITY_PROTOCOL                       = "SASL_SSL"
      SPRING_KAFKA_PROPERTIES_SASL_MECHANISM               = "AWS_MSK_IAM"
      SPRING_KAFKA_PROPERTIES_SASL_JAAS_CONFIG             = "software.amazon.msk.auth.iam.IAMLoginModule required;"
      SPRING_KAFKA_PROPERTIES_SASL_CLIENT_CALLBACK_HANDLER_CLASS = "software.amazon.msk.auth.iam.IAMClientCallbackHandler"
    },
    each.value.app_bucket ? { APP_S3_BUCKET = module.app_bucket[each.key].id } : {},
    each.value.environment,
  )

  secrets = merge(
    {
      DB_PASSWORD    = "${module.db[each.key].master_user_secret_arn}:password::"
      REDIS_PASSWORD = module.redis.auth_secret_arn
    },
    { for k, s in local.app_secrets : s.env => aws_secretsmanager_secret.app[k].arn if s.service == each.key },
  )

  task_role_policy_json = data.aws_iam_policy_document.task[each.key].json

  alb_arn_suffix         = module.alb.alb_arn_suffix
  prod_listener_arn      = module.alb.https_listener_arn
  test_listener_arn      = module.alb.test_listener_arn
  host_headers           = ["${each.value.subdomain}.${var.domain_name}"]
  listener_rule_priority = each.value.priority

  deployment_config_name    = each.value.deployment_config_name
  wait_for_approval_minutes = each.value.wait_for_approval_minutes
  alarm_topic_arns          = [aws_sns_topic.alerts.arn]
  kms_key_arn               = aws_kms_key.platform.arn
}

module "pipeline" {
  source   = "../modules/pipeline"
  for_each = var.services

  name           = "${local.name}-${each.key}"
  connection_arn = var.github_connection_arn
  repository     = each.value.repository
  branch         = each.value.branch
  test_command   = each.value.test_command

  ecr_repository_url = module.ecr[each.key].repository_url
  ecr_repository_arn = module.ecr[each.key].repository_arn

  task_definition_family           = module.service[each.key].task_definition_family
  container_name                   = module.service[each.key].container_name
  task_role_arns                   = [module.service[each.key].task_role_arn, module.service[each.key].execution_role_arn]
  codedeploy_app_name              = module.service[each.key].codedeploy_app_name
  codedeploy_deployment_group_name = module.service[each.key].codedeploy_deployment_group_name

  artifact_bucket_name    = module.artifacts.id
  artifact_bucket_arn     = module.artifacts.arn
  kms_key_arn             = aws_kms_key.platform.arn
  require_manual_approval = each.value.require_manual_approval
  approval_topic_arns     = [aws_sns_topic.alerts.arn]
}
