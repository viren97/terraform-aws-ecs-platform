variable "name" {
  type = string
}

variable "connection_arn" {
  description = "CodeConnections (CodeStar) connection to GitHub, authorised once in the console."
  type        = string
}

variable "repository" {
  description = "owner/repo of the service source."
  type        = string
}

variable "branch" {
  type    = string
  default = "main"
}

variable "test_command" {
  description = "Command run before the image build, e.g. ./gradlew test. Empty skips tests."
  type        = string
  default     = ""
}

variable "ecr_repository_url" {
  type = string
}

variable "ecr_repository_arn" {
  type = string
}

variable "task_definition_family" {
  type = string
}

variable "container_name" {
  type = string
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "task_role_arns" {
  description = "Task and execution role ARNs CodePipeline passes when registering a new revision."
  type        = list(string)
}

variable "codedeploy_app_name" {
  type = string
}

variable "codedeploy_deployment_group_name" {
  type = string
}

variable "artifact_bucket_name" {
  type = string
}

variable "artifact_bucket_arn" {
  type = string
}

variable "cpu_architecture" {
  type    = string
  default = "ARM64"
}

variable "build_compute_type" {
  type    = string
  default = "BUILD_GENERAL1_MEDIUM"
}

variable "require_manual_approval" {
  type    = bool
  default = false
}

variable "approval_topic_arns" {
  type    = list(string)
  default = []
}

variable "kms_key_arn" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
