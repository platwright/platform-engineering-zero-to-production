output "config_path" {
  description = "Path to the generated service config file."
  value       = local_file.config.filename
}

output "token" {
  description = "Generated service token (sensitive)."
  value       = random_password.token.result
  sensitive   = true
}
