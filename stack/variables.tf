variable "project" {
  type    = string
  default = "viren-platform"
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "domain_name" {
  description = "Base domain. Services are served at <subdomain>.<domain_name>."
  type        = string
}

variable "certificate_arn" {
  description = "ACM wildcard certificate for *.<domain_name> in this region."
  type        = string
}

variable "github_connection_arn" {
  description = "CodeConnections connection to GitHub (authorise once in the console)."
  type        = string
}

variable "alarm_email" {
  description = "Optional email subscribed to deploy/alarm notifications."
  type        = string
  default     = null
}

# ---- sizing knobs that differ per environment
variable "az_count" {
  type    = number
  default = 3
}

variable "single_nat_gateway" {
  type    = bool
  default = false
}

variable "redis" {
  type = object({
    node_type = string
    replicas  = number
  })
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "test_listener_cidrs" {
  description = "Who may hit green on the test listener before cut-over (office / VPN CIDRs)."
  type        = list(string)
  default     = []
}

# ---- the services this platform hosts
variable "services" {
  description = "Services hosted on the platform. Each gets its own database, ECR repo, pipeline and canary blue/green deploy."
  type        = map(object({
    short_name   = string
    repository   = string
    branch       = optional(string, "main")
    subdomain    = string
    priority     = number
    test_command = optional(string, "")

    cpu       = optional(number, 512)
    memory    = optional(number, 1024)
    min_count = optional(number, 2)
    max_count = optional(number, 6)

    database = object({
      name           = string
      username       = string
      instance_class = optional(string, "db.t4g.micro")
      multi_az       = optional(bool, true)
    })

    kafka = object({
      topic_patterns = list(string)
      group_patterns = list(string)
    })

    app_bucket  = optional(bool, false)
    app_secrets = optional(list(string), [])
    environment = optional(map(string), {})

    deployment_config_name    = optional(string, "CodeDeployDefault.ECSCanary10Percent5Minutes")
    require_manual_approval   = optional(bool, false)
    wait_for_approval_minutes = optional(number, 0)
  }))
}
