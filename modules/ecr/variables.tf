variable "name" {
  type = string
}

variable "kms_key_arn" {
  description = "KMS key for image encryption. Null uses the AWS-managed ECR key."
  type        = string
  default     = null
}

variable "keep_images" {
  description = "How many tagged images to retain (enough to roll back)."
  type        = number
  default     = 30
}

variable "force_delete" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
