terraform {
  required_version = ">= 1.6"
}

# Each environment is its own ROOT MODULE → its own state file in this directory →
# blast-radius isolation. A mistake here cannot address staging or prod resources.
#
# In production, replace the implicit local backend with a DISTINCT remote backend
# per environment, e.g.:
#   terraform { backend "gcs" { bucket = "acme-tf-state"; prefix = "dev" } }

module "assets" {
  source      = "../../modules/bucket"
  name        = "assets"
  environment = "dev"
  versioning  = false # dev doesn't need versioning
}

output "bucket_name" {
  value = module.assets.bucket_name
}
