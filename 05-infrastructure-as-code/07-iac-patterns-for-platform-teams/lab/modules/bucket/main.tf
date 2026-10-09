# Free stand-in for a cloud storage bucket. In production the body would be a
# google_storage_bucket (or aws_s3_bucket); the interface stays identical, so
# environments and the promotion/versioning workflow don't change.

resource "random_id" "suffix" {
  byte_length = 3
}

resource "local_file" "bucket" {
  filename = "${path.root}/generated/${var.environment}-${var.name}.bucket"

  content = <<-EOT
    name=${var.name}-${random_id.suffix.hex}
    environment=${var.environment}
    versioning=${var.versioning}
  EOT
}
