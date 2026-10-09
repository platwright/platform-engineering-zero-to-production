terraform {
  required_version = ">= 1.6"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Talks to your local Docker Engine. No cloud account, no cost.
provider "docker" {}

# A random, human-friendly suffix so container names don't collide.
resource "random_pet" "suffix" {
  length = 1
}

# Pull the image once; every container references it (an implicit dependency).
resource "docker_image" "nginx" {
  name         = var.image
  keep_locally = true
}

# One container per entry in var.services. for_each keys by service name, so
# adding or removing a service never disturbs the others.
resource "docker_container" "svc" {
  for_each = var.services

  name  = "${each.key}-${random_pet.suffix.id}"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = each.value
  }

  labels {
    label = "managed-by"
    value = "terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}
