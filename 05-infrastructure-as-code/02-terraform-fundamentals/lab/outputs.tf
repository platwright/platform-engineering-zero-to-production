output "container_names" {
  description = "The actual names Terraform assigned to each container."
  value       = { for name, c in docker_container.svc : name => c.name }
}

output "service_urls" {
  description = "Open these in a browser after apply."
  value       = [for name, port in var.services : "http://localhost:${port}"]
}

output "suffix" {
  description = "The random suffix shared by all containers this run."
  value       = random_pet.suffix.id
}
