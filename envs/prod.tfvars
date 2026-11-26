environment = "prod"
region      = "ap-south-1"

domain_name           = "example.com"
certificate_arn       = "arn:aws:acm:ap-south-1:111111111111:certificate/REPLACE_ME"
github_connection_arn = "arn:aws:codeconnections:ap-south-1:111111111111:connection/REPLACE_ME"
alarm_email           = "oncall@example.com"

# One NAT per AZ, Multi-AZ data stores, deletion protection on.
az_count            = 3
single_nat_gateway  = false
deletion_protection = true
test_listener_cidrs = ["203.0.113.0/24"] # office / VPN

redis = {
  node_type = "cache.t4g.small"
  replicas  = 1
}

services = {
  "wallet-ledger-service" = {
    short_name   = "wall"
    repository   = "viren97/wallet-ledger-service"
    subdomain    = "wallet"
    priority     = 10
    test_command = "./gradlew test --no-daemon"

    database = {
      name           = "tms"
      username       = "tms"
      instance_class = "db.t4g.medium"
      multi_az       = true
    }

    kafka = {
      topic_patterns = ["transaction.*"]
      group_patterns = ["tms*"]
    }

    # Settlement / reconciliation files.
    app_bucket  = true
    app_secrets = ["BANK_WEBHOOK_HMAC_SECRET"]

    min_count               = 2
    require_manual_approval = true
  }

  "goal-coach-service" = {
    short_name   = "coach"
    repository   = "viren97/goal-coach-service"
    subdomain    = "coach"
    priority     = 20
    test_command = "./gradlew test --no-daemon"

    database = {
      name     = "coach"
      username = "coach"
      multi_az = true
    }

    kafka = {
      topic_patterns = ["coach.*"]
      group_patterns = ["coach*"]
    }

    app_secrets = ["ANTHROPIC_API_KEY", "FCM_SERVICE_ACCOUNT_JSON"]
    environment = {
      COACH_AI_PROVIDER   = "claude"
      COACH_PUSH_PROVIDER = "fcm"
      FCM_PROJECT_ID      = "coach-prod"
    }

    min_count               = 2
    require_manual_approval = true
  }
}
