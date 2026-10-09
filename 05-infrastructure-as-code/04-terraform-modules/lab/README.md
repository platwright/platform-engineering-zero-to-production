# Lab — Build an Internal Module Library (Local & Free)

> You'll build a reusable Terraform **module** and consume it from **two
> environments** (`dev` and `prod`) that differ only by inputs — the exact structure
> real platform teams use for a GKE module library, implemented locally with free
> providers so it costs nothing.

**Estimated time:** ~50–70 minutes
**Type:** Build
**Deliverable:** A working `modules/service` module composed by `environments/dev`
and `environments/prod`, plus a small interface improvement you add yourself.

## Objectives

- Understand the module file layout (`variables.tf`, `main.tf`, `outputs.tf`,
  `versions.tf`, `README.md`).
- Call one module from two root modules with different inputs.
- Use **defaults** and **input validation** in a module interface.
- Practise a **versioned upgrade** by changing the module and re-applying consumers.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) or
  [OpenTofu](https://opentofu.org/docs/intro/install/) on your `PATH`.
- Starter files in this folder:
  - [`modules/service/`](./modules/service/) — the reusable module skeleton.
  - [`environments/dev/main.tf`](./environments/dev/main.tf) and
    [`environments/prod/main.tf`](./environments/prod/main.tf) — the consumers.

> **Cost note:** The module uses only the `random` and `local` providers — **zero
> cloud spend.** It is deliberately shaped like a real cluster module; see the GKE
> code in [the lesson](../README.md) for the production equivalent.

## Steps

1. **Read the module.** Open [`modules/service/variables.tf`](./modules/service/variables.tf)
   (the interface), [`outputs.tf`](./modules/service/outputs.tf) (the return values),
   and [`main.tf`](./modules/service/main.tf) (the implementation). Notice `replicas`
   and `log_level` have **defaults** and **validation** blocks.

2. **Apply the dev environment.** It calls the module twice (payments + orders):

   ```bash
   cd 05-infrastructure-as-code/04-terraform-modules/lab/environments/dev
   terraform init
   terraform apply -auto-approve
   ```

   Inspect the generated files — note `payments` is `debug`/1 replica while `orders`
   took the **defaults** (`info`/2 replicas):

   ```bash
   cat generated/dev-payments.conf
   cat generated/dev-orders.conf
   ```

3. **Apply the prod environment.** Same module, different inputs:

   ```bash
   cd ../prod
   terraform init
   terraform apply -auto-approve
   cat generated/prod-payments.conf    # replicas=6, log_level=warn
   ```

   One module definition now drives two environments. That is the whole point: change
   the module once, every environment benefits.

4. **Feel a validation failure.** From `environments/prod`, try an invalid input and
   watch the interface reject it *at plan time* with your custom message:

   ```bash
   terraform plan -var 'replicas=999'    # fails: replicas must be between 1 and 50
   ```

   (That `-var` only affects this run; it isn't wired to the module call, so expect a
   variable-not-declared note — the point is to see validation messages. To truly
   test it, temporarily set `replicas = 999` in the module call and run `plan`.)

5. **Extend the interface (the real exercise).** Add a new input to the module and
   thread it through. For example, add a `region` variable (default `"europe-west1"`)
   to [`modules/service/variables.tf`](./modules/service/variables.tf), include it in
   the generated config in `main.tf`, then set a different `region` per environment.
   Re-apply both environments and confirm each config reflects its region. This is
   exactly how a module evolves: add an input, give it a safe default so existing
   consumers don't break, let environments override.

## Expected result

- `dev` and `prod` each produce two config files via the **same** module.
- `orders` in dev uses module **defaults**; `payments` overrides them.
- An out-of-range `replicas` is rejected by the module's **validation** with your
  error message.
- After step 5, both environments show your new `region` field, defaulted where not
  overridden.

## Cleanup

> Always tear down each environment you applied.

```bash
# in environments/dev AND environments/prod:
terraform destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl terraform.tfstate* generated
```

## Reflection

- `orders` in dev never specified `log_level`, yet it works. Where did `info` come
  from, and why are good defaults the difference between a two-line and a twenty-line
  module call?
- You changed behavior for *both* environments by editing one module in step 5. In a
  real org with many consumers, why would you **tag** that change as a new version
  and let teams adopt it deliberately rather than forcing it instantly?
- The module's interface (`variables`/`outputs`) stayed stable even though its body
  is trivial here. Why does a stable interface let you later swap the body for a real
  GKE cluster without consumers changing a line?

## Stretch goals (optional)

- Add a `staging` environment that sits between dev and prod, reusing the same
  module.
- Introduce a second small module (e.g. `bucket` that writes a different file) and
  **compose** it: feed one module's output into the other's input.
- Simulate versioning: copy `modules/service` to `modules/service-v2`, make a
  breaking input rename, and point only `prod` at v2 — proving consumers upgrade
  independently.
