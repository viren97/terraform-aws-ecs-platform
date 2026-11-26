variable "name" {
  type = string
}

variable "container_insights" {
  description = "Container Insights mode: enhanced, enabled or disabled."
  type        = string
  default     = "enhanced"

  validation {
    condition     = contains(["enhanced", "enabled", "disabled"], var.container_insights)
    error_message = "container_insights must be enhanced, enabled or disabled."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
