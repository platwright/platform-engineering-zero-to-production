terraform {
  required_version = ">= 1.6"
}

# Own root module, own state → isolated from dev and prod.
# Production backend (distinct prefix):
#   terraform { backend "gcs" { bucket = "acme-tf-state"; prefix = "staging" } }

module "assets" {
  source      = "../../modules/bucket"
  name        = "assets"
  environment = "staging"
  versioning  = true
}

output "bucket_name" {
  value = module.assets.bucket_name
}
