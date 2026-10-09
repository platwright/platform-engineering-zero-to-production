output "bucket_name" {
  description = "The globally-unique generated bucket name."
  value       = "${var.name}-${random_id.suffix.hex}"
}
