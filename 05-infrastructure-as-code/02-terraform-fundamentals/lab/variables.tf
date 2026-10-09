variable "image" {
  type        = string
  default     = "nginx:1.27-alpine"
  description = "Container image to run for each service."
}

variable "services" {
  type = map(number)

  default = {
    web   = 8081
    admin = 8082
  }

  description = "Map of service name to the host port it should listen on."
}
