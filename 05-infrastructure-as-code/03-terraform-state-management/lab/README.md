# Lab — State Migration and Surgery (Local & Free)

> You'll treat Terraform state as the production asset it is: inspect it, **migrate it
> to a different backend**, trigger a **state lock** with a concurrent apply, and
> perform **state surgery** (`state mv`, `state rm`) — proving that none of it touched
> the real resources. Everything runs on the local backend, so it's completely free.

**Estimated time:** ~45–60 minutes
**Type:** Build / debug
**Deliverable:** A migrated state file plus notes showing a successful rename via
`state mv` with a clean `plan` (no destroy/create).

## Objectives

- Inspect state with `state list` / `state show`.
- Migrate state from the default backend to a configured local backend.
- Observe **state locking** block a concurrent apply.
- Rename a resource safely with `state mv`, and detach one with `state rm`.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) or
  [OpenTofu](https://opentofu.org/docs/intro/install/) on your `PATH`.
- Two terminal windows for the locking step.
- Starter files in this folder: [`main.tf`](./main.tf) and
  [`backend.tf.example`](./backend.tf.example).

> **Cost note:** Uses only the `random` and `time` providers on a local backend —
> **zero cloud spend.** The GCS backend block in [the lesson](../README.md) is for
> reading only.

## Steps

1. **Apply on the default backend.** Initialize and create the resources:

   ```bash
   cd 05-infrastructure-as-code/03-terraform-state-management/lab
   terraform init
   terraform apply -auto-approve
   ```

   State lands in `./terraform.tfstate`. Inspect it:

   ```bash
   terraform state list
   terraform state show random_pet.service
   ```

2. **Back up state before doing anything risky.** This habit will save you in
   production:

   ```bash
   terraform state pull > backup.tfstate
   ```

3. **Migrate to a configured backend.** Copy the example backend and re-init.
   Terraform detects the backend change and offers to move your existing state:

   ```bash
   cp backend.tf.example backend.tf
   terraform init -migrate-state
   ```

   Answer `yes` when asked to copy existing state. Confirm the state moved into
   `./state/platform.tfstate` and that nothing needs changing:

   ```bash
   ls state/
   terraform plan      # "No changes." — migration moved the map, not the resources
   ```

4. **Observe state locking.** In **terminal 1**, start an apply that forces a change
   (the `time_sleep` resource takes ~20s), giving you a window:

   ```bash
   terraform apply -replace=time_sleep.slow -auto-approve
   ```

   Quickly, in **terminal 2**, try another operation against the same state:

   ```bash
   terraform plan
   ```

   You should see **"Error acquiring the state lock."** The lock is doing its job —
   preventing concurrent writes that would corrupt state. Let terminal 1 finish; the
   lock releases and terminal 2 works again.

5. **State surgery — safe rename.** Rename the resource in code and move it in state
   so the *same* object keeps its identity. Edit `main.tf`, changing
   `resource "random_pet" "service"` to `resource "random_pet" "web"` (and update the
   two output references from `random_pet.service.id` to `random_pet.web.id`). Then:

   ```bash
   terraform state mv random_pet.service random_pet.web
   terraform plan      # "No changes." — nothing destroyed or recreated
   ```

   Without `state mv`, that rename would have **destroyed and recreated** the
   resource. The move updated only the map.

6. **State surgery — detach.** Tell Terraform to forget a resource *without*
   destroying it:

   ```bash
   terraform state rm time_sleep.slow
   terraform state list        # time_sleep.slow is gone from management
   terraform plan              # Terraform now wants to CREATE it again (it forgot)
   ```

   This shows `state rm` stops management; it does **not** delete the real thing.
   Re-apply to bring it back under management if you like.

## Expected result

- State migrated from `terraform.tfstate` to `state/platform.tfstate` with a clean
  `plan`.
- A concurrent operation was blocked by a state lock.
- A resource rename produced **"No changes"** after `state mv` (no destroy/recreate).
- `state rm` removed a resource from management without deleting anything real.

## Cleanup

> Always tear down. Even local resources leave files and (briefly) a lock.

```bash
terraform destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl terraform.tfstate* state backup.tfstate backend.tf
```

## Reflection

- In step 5, what exactly would Terraform have done if you had renamed the resource
  in code but *skipped* `state mv`? Why is that catastrophic for a database or a disk
  instead of a `random_pet`?
- The lock error in step 4 is annoying but protective. What would have happened to
  your state file if Terraform let both operations write at once?
- You migrated a *local* backend to another *local* path. Which single line would you
  change to make `state/platform.tfstate` live in a shared GCS bucket instead — and
  why does that one change unlock safe team collaboration?

## Stretch goals (optional)

- Use a `moved {}` block in `main.tf` to express the rename *declaratively* instead
  of running `state mv`, and confirm `plan` still shows no changes.
- Create a second workspace (`terraform workspace new staging`) and show it has its
  own empty state, separate from `default`.
- Corrupt a copy of your state (delete one resource's block by hand), run `plan`, and
  observe how Terraform reacts — then restore from `backup.tfstate` with
  `terraform state push`.
