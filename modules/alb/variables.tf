variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate for the HTTPS listeners."
  type        = string
}

variable "allowed_cidrs" {
  description = "CIDRs allowed to reach the public listeners."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "test_listener_port" {
  description = "Port of the blue/green test listener used to hit green before cut-over."
  type        = number
  default     = 8443
}

variable "test_listener_cidrs" {
  description = "CIDRs allowed on the test listener (keep this to your office/VPN)."
  type        = list(string)
  default     = []
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "access_logs_bucket" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
