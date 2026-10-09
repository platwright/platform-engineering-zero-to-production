terraform {
  required_version = ">= 1.6"
}

# dev environment: small replicas, verbose logging.
module "payments" {
  source      = "../../modules/service"
  name        = "payments"
  environment = "dev"
  replicas    = 1
  log_level   = "debug"
}

module "orders" {
  source      = "../../modules/service"
  name        = "orders"
  environment = "dev"
  # replicas and log_level intentionally omitted — they use the module defaults.
}

output "config_paths" {
  value = [module.payments.config_path, module.orders.config_path]
}
