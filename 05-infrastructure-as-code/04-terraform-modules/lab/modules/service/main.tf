# Stand-in for "provision a service environment". Uses free providers so the lab
# costs nothing; swap these resources for a GKE cluster + node pool in production
# and the module interface (variables/outputs) stays the same.

resource "random_password" "token" {
  length  = 20
  special = false
}

resource "local_file" "config" {
  filename = "${path.root}/generated/${var.environment}-${var.name}.conf"

  content = <<-EOT
    name=${var.name}
    environment=${var.environment}
    replicas=${var.replicas}
    log_level=${var.log_level}
    token=${random_password.token.result}
  EOT
}
