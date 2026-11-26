environment = "dev"
region      = "ap-south-1"

domain_name           = "dev.example.com"
certificate_arn       = "arn:aws:acm:ap-south-1:111111111111:certificate/REPLACE_ME"
github_connection_arn = "arn:aws:codeconnections:ap-south-1:111111111111:connection/REPLACE_ME"

# Cheap and disposable.
az_count            = 2
single_nat_gateway  = true
deletion_protection = false

redis = {
  node_type = "cache.t4g.micro"
  replicas  = 0
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
      instance_class = "db.t4g.micro"
      multi_az       = false
    }

    kafka = {
      topic_patterns = ["transaction.*"]
      group_patterns = ["tms*"]
    }

    # Settlement / reconciliation files.
    app_bucket  = true
    app_secrets = ["BANK_WEBHOOK_HMAC_SECRET"]

    min_count               = 1
    require_manual_approval = false
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
      multi_az = false
    }

    kafka = {
      topic_patterns = ["coach.*"]
      group_patterns = ["coach*"]
    }

    app_secrets = ["ANTHROPIC_API_KEY", "FCM_SERVICE_ACCOUNT_JSON"]
    environment = {
      COACH_AI_PROVIDER   = "claude"
      COACH_PUSH_PROVIDER = "fcm"
      FCM_PROJECT_ID      = "coach-dev"
    }

    min_count               = 1
    require_manual_approval = false
  }
}
