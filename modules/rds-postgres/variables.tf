variable "name" {
  description = "Instance identifier, usually the owning service's name."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Isolated data-tier subnets."
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to connect on 5432 (the owning service's tasks)."
  type        = list(string)
}

variable "database_name" {
  type = string
}

variable "username" {
  type = string
}

variable "major_version" {
  type    = string
  default = "16"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling in GiB."
  type        = number
  default     = 100
}

variable "multi_az" {
  type    = bool
  default = true
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "enhanced_monitoring" {
  type    = bool
  default = false
}

variable "slow_query_ms" {
  description = "Log statements slower than this."
  type        = number
  default     = 500
}

variable "kms_key_arn" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
