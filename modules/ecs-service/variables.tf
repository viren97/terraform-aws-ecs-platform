variable "name" {
  description = "Service name; also the container, task family, CodeDeploy app and log group name."
  type        = string
}

variable "short_name" {
  description = "Up to 5 chars, used as target group name prefix (ALB names are limited to 32 chars)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{1,5}$", var.short_name))
    error_message = "short_name must be 1-5 lowercase letters or digits."
  }
}

# ---- placement
variable "cluster_name" {
  type = string
}

variable "cluster_arn" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Private app-tier subnets for the tasks."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Task security groups. Created by the caller so data stores can reference them without a cycle."
  type        = list(string)
}

# ---- container
variable "image" {
  description = "Initial image. Later releases are rolled out by CodeDeploy, not Terraform."
  type        = string
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "cpu" {
  type    = number
  default = 512
}

variable "memory" {
  type    = number
  default = 1024
}

variable "cpu_architecture" {
  description = "ARM64 (Graviton, ~20% cheaper) or X86_64."
  type        = string
  default     = "ARM64"

  validation {
    condition     = contains(["ARM64", "X86_64"], var.cpu_architecture)
    error_message = "cpu_architecture must be ARM64 or X86_64."
  }
}

variable "environment" {
  description = "Plain environment variables."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Env var name -> Secrets Manager ARN (optionally with :json-key:: suffix). Injected at start, never in the task definition."
  type        = map(string)
  default     = {}
}

variable "task_role_policy_json" {
  description = "Least-privilege IAM policy for the application (Kafka topics, S3 prefixes, ...)."
  type        = string
  default     = null
}

variable "health_check_path" {
  type    = string
  default = "/actuator/health/readiness"
}

variable "container_health_check_command" {
  description = "Optional in-container health check command, e.g. [\"CMD-SHELL\", \"wget -qO- localhost:8080/actuator/health/liveness\"]."
  type        = list(string)
  default     = null
}

variable "health_check_grace_seconds" {
  description = "JVM warm-up time before health checks count."
  type        = number
  default     = 90
}

variable "enable_execute_command" {
  type    = bool
  default = true
}

# ---- routing
variable "alb_arn_suffix" {
  type = string
}

variable "prod_listener_arn" {
  type = string
}

variable "test_listener_arn" {
  type = string
}

variable "host_headers" {
  description = "Host names routed to this service, e.g. [\"wallet.example.com\"]."
  type        = list(string)
}

variable "listener_rule_priority" {
  description = "Unique per listener."
  type        = number
}

# ---- scaling
variable "min_count" {
  type    = number
  default = 2
}

variable "max_count" {
  type    = number
  default = 6
}

variable "cpu_target_percent" {
  type    = number
  default = 60
}

# ---- deployment
variable "deployment_config_name" {
  description = "CodeDeploy traffic-shifting config, e.g. CodeDeployDefault.ECSCanary10Percent5Minutes or CodeDeployDefault.ECSAllAtOnce."
  type        = string
  default     = "CodeDeployDefault.ECSCanary10Percent5Minutes"
}

variable "wait_for_approval_minutes" {
  description = "If > 0, green waits on the test listener for a manual 'continue' before any prod traffic shifts."
  type        = number
  default     = 0
}

variable "blue_termination_wait_minutes" {
  description = "How long the old (blue) tasks stay up after success, for instant rollback."
  type        = number
  default     = 15
}

variable "error_rate_threshold_percent" {
  description = "Target 5xx % that triggers rollback."
  type        = number
  default     = 2
}

variable "p99_latency_threshold_seconds" {
  type    = number
  default = 1.5
}

variable "alarm_topic_arns" {
  description = "SNS topics notified when deploy-guarding alarms change state."
  type        = list(string)
  default     = []
}

# ---- misc
variable "log_retention_days" {
  type    = number
  default = 30
}

variable "kms_key_arn" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
