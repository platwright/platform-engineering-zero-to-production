# Lab — Your First Terraform Project (Local & Free)

> You'll provision **real infrastructure with Terraform** — several nginx containers
> on your local Docker Engine — using providers, variables, `for_each`, and outputs.
> Everything runs locally and costs nothing, while exercising the exact
> `init → plan → apply → destroy` workflow you'd use against GKE.

**Estimated time:** ~45–60 minutes
**Type:** Build
**Deliverable:** A working Terraform project that stands up and tears down a set of
containers, plus answers to the reflection questions.

## Objectives

- Run the full Terraform workflow: `init`, `fmt`, `validate`, `plan`, `apply`,
  `destroy`.
- Use **variables**, **outputs**, and the **`for_each`** meta-argument.
- Observe an **implicit dependency** (containers depend on the image) in the plan.
- Prove **idempotency**: a second `apply` reports no changes.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) **or**
  [OpenTofu](https://opentofu.org/docs/intro/install/) on your `PATH`
  (`terraform version` or `tofu version`).
- **Docker** running locally (from [Phase 2](../../../02-containerization/) and
  [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)).
- The starter files in this folder: [`main.tf`](./main.tf),
  [`variables.tf`](./variables.tf), [`outputs.tf`](./outputs.tf).

> **Cost note:** This lab uses the local Docker provider only — **zero cloud spend.**
> The GKE code in [the lesson](../README.md) is for reading; do not apply it unless
> you have a GCP project and accept its cost (and if you do, destroy it immediately).

## Steps

1. **Initialize.** From this folder, download the providers declared in `main.tf`:

   ```bash
   cd 05-infrastructure-as-code/02-terraform-fundamentals/lab
   terraform init
   ```

   Terraform creates `.terraform/` and a `.terraform.lock.hcl`. This is `init`
   setting up the `docker` and `random` providers.

2. **Format and validate.** Catch style and syntax issues before planning:

   ```bash
   terraform fmt
   terraform validate
   ```

   `validate` should say *"Success! The configuration is valid."*

3. **Plan.** See what Terraform intends to do — read it carefully:

   ```bash
   terraform plan
   ```

   You should see a plan to add a `random_pet`, a `docker_image`, and **two**
   `docker_container` resources (keyed `web` and `admin`). Notice the containers
   reference `docker_image.nginx.image_id` — an **implicit dependency**, so the image
   is created first.

4. **Apply.** Enact the plan and create real containers:

   ```bash
   terraform apply -auto-approve
   ```

   When it finishes, Terraform prints your outputs. Confirm the containers exist and
   respond:

   ```bash
   docker ps --filter "label=managed-by=terraform"
   curl -s http://localhost:8081 | head -n 5
   ```

5. **Prove idempotency.** Run apply again without changing anything:

   ```bash
   terraform apply -auto-approve
   ```

   The result is **"No changes. Your infrastructure matches the configuration."**
   Re-running is safe — the core IaC property from Module 05.1.

6. **Change desired state with a variable.** Add a third service *without editing
   `main.tf`* by overriding the `services` variable:

   ```bash
   terraform apply -auto-approve \
     -var 'services={web=8081,admin=8082,metrics=8083}'
   ```

   The plan adds exactly **one** container (`metrics`) and leaves `web` and `admin`
   untouched — that's `for_each`'s stable keys at work. Verify:

   ```bash
   curl -s http://localhost:8083 | head -n 1
   ```

7. **Inspect state.** See what Terraform is tracking:

   ```bash
   terraform state list
   terraform show | head -n 30
   ```

## Expected result

- `terraform apply` creates three (or two) running nginx containers reachable on
  `localhost` ports.
- A second `apply` reports **no changes** (idempotency).
- Overriding the `services` variable adds/removes containers surgically, without
  churning the others.
- `terraform state list` shows `random_pet.suffix`, `docker_image.nginx`, and one
  `docker_container.svc["<name>"]` per service.

## Cleanup

> Always destroy what you create. These are local containers, but leaving them
> running wastes resources and ports.

```bash
terraform destroy -auto-approve
docker ps --filter "label=managed-by=terraform"   # should be empty
```

Optionally remove the local Terraform working files:

```bash
rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
```

## Reflection

- You never told Terraform to create the image *before* the containers — how did it
  know? Point at the exact line that created the dependency.
- You changed infrastructure by passing a different `-var`, not by editing resource
  blocks. Why is parameterizing with variables the seam that later becomes a reusable
  module (Module 05.4)?
- `terraform apply` wrote a `terraform.tfstate` file. Open it. What would break if a
  teammate ran this same project and produced their *own* state file? (This is
  exactly the problem Module 05.3 solves.)

## Stretch goals (optional)

- Add a `lifecycle { prevent_destroy = true }` to one container and watch `destroy`
  refuse — then remove it to clean up.
- Add a `terraform_data` resource with a `triggers_replace` on the image tag, and a
  `provisioner "local-exec"` that prints a message on every image change.
- Convert `services` from `map(number)` to a richer `map(object({...}))` carrying
  both a port and an image per service.
