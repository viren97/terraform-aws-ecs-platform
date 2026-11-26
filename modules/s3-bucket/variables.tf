variable "name" {
  type = string
}

variable "kms_key_arn" {
  description = "KMS key for SSE-KMS. Null falls back to SSE-S3."
  type        = string
  default     = null
}

variable "versioning" {
  type    = bool
  default = true
}

variable "expiration_days" {
  description = "Expire current objects after N days (e.g. pipeline artifacts). Null keeps them."
  type        = number
  default     = null
}

variable "noncurrent_version_expiration_days" {
  type    = number
  default = 30
}

variable "extra_policy_json" {
  description = "Additional bucket policy statements merged with the TLS-only deny."
  type        = string
  default     = null
}

variable "force_destroy" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
