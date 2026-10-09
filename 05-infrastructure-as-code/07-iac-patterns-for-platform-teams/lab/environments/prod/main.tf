terraform {
  required_version = ">= 1.6"
}

# Own root module, own state → a dev/staging mistake cannot reach prod.
# Production backend (distinct prefix):
#   terraform { backend "gcs" { bucket = "acme-tf-state"; prefix = "prod" } }

module "assets" {
  source      = "../../modules/bucket"
  name        = "assets"
  environment = "prod"
  versioning  = true
}

output "bucket_name" {
  value = module.assets.bucket_name
}
