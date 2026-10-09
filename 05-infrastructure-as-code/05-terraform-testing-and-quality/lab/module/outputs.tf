output "config_path" {
  description = "Path to the generated config file (asserted by Terratest)."
  value       = local_file.config.filename
}

output "service_id" {
  description = "The generated service id."
  value       = random_pet.id.id
}
