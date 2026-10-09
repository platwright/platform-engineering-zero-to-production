variable "name" {
  type        = string
  description = "Logical bucket name (a global-unique suffix is appended)."
}

variable "environment" {
  type        = string
  description = "Environment this bucket belongs to."
}

variable "versioning" {
  type        = bool
  default     = true
  description = "Whether object versioning is enabled."
}
