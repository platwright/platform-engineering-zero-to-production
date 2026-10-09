terraform {
  required_version = ">= 1.6"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

resource "random_pet" "service" {
  length = 2
}

resource "random_integer" "replicas" {
  min = 2
  max = 6
}

# Takes ~20s to create, giving you a window to run a second apply from another
# terminal and observe STATE LOCKING in action. No cloud, no cost.
resource "time_sleep" "slow" {
  create_duration = "20s"

  triggers = {
    pet = random_pet.service.id
  }
}

output "service_name" {
  value = random_pet.service.id
}

output "replicas" {
  value = random_integer.replicas.result
}
