variable "name" {
  type        = string
  default     = "demo"
  description = "Service name used for the generated config file."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.name))
    error_message = "name must be lowercase alphanumeric with dashes, starting with a letter."
  }
}
