terraform {
  required_version = ">= 1.5"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# The `local` provider needs no cloud account or credentials, so `init`, `plan`,
# and `apply` all work for free on your machine — perfect for practising the
# plan -> review -> apply loop and simulating drift.

resource "local_file" "greeting" {
  content  = "hello from a plan-on-PR / apply-on-merge pipeline\n"
  filename = "${path.module}/greeting.txt"
}

output "greeting_path" {
  description = "Path to the file this configuration manages."
  value       = local_file.greeting.filename
}
