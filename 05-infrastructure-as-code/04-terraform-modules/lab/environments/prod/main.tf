terraform {
  required_version = ">= 1.6"
}

# prod environment: more replicas, quieter logging. SAME module, different inputs.
module "payments" {
  source      = "../../modules/service"
  name        = "payments"
  environment = "prod"
  replicas    = 6
  log_level   = "warn"
}

module "orders" {
  source      = "../../modules/service"
  name        = "orders"
  environment = "prod"
  replicas    = 4
  log_level   = "info"
}

output "config_paths" {
  value = [module.payments.config_path, module.orders.config_path]
}
