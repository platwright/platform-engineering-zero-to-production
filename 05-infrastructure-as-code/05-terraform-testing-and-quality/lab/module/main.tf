# A deliberately tiny, free module so Terratest can apply/destroy it in seconds
# with no cloud cost. The policy in ../policy enforces that files land under
# ./generated/ — a stand-in for a real rule like "every bucket must be private".

resource "random_pet" "id" {
  length = 2
}

resource "local_file" "config" {
  filename = "${path.module}/generated/${var.name}.conf"

  content = <<-EOT
    name=${var.name}
    id=${random_pet.id.id}
  EOT
}
