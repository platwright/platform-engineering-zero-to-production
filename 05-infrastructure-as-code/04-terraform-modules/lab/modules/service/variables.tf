variable "name" {
  type        = string
  description = "Service name, e.g. \"payments\"."
}

variable "environment" {
  type        = string
  description = "Environment this service belongs to (dev, staging, prod)."
}

variable "replicas" {
  type        = number
  default     = 2
  description = "Desired replica count."

  validation {
    condition     = var.replicas >= 1 && var.replicas <= 50
    error_message = "replicas must be between 1 and 50."
  }
}

variable "log_level" {
  type        = string
  default     = "info"
  description = "Log verbosity for the service."

  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "log_level must be one of: debug, info, warn, error."
  }
}
