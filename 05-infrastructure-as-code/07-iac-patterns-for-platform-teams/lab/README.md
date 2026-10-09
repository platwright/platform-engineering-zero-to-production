# Lab — Build a Platform IaC Mono-Repo (Local & Free)

> You'll assemble everything from this phase into the structure a platform team
> actually runs: reusable **modules**, isolated **dev/staging/prod** environments each
> with their own state, **plan-on-PR / apply-on-merge** workflow skeletons, and a
> **drift-detection** script using `plan -detailed-exitcode`. It all runs locally with
> `plan`/`apply` on free providers — no cost.

**Estimated time:** ~50–70 minutes
**Type:** Build / design
**Deliverable:** A working mono-repo where each environment plans/applies
independently, plus a drift-check script that reports per-environment drift.

## Objectives

- Lay out `modules/` + `environments/{dev,staging,prod}` with isolated state.
- Promote a change dev → staging → prod by applying each environment in turn.
- Observe **blast-radius isolation**: each environment is a separate state.
- Run **drift detection** and read its exit codes.
- Read the **plan-on-PR / apply-on-merge** workflow skeletons.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) or
  [OpenTofu](https://opentofu.org/docs/intro/install/).
- `bash` for the drift script (WSL2 on Windows).
- Starter files in this folder:
  - [`modules/bucket/`](./modules/bucket/) — a free, reusable module.
  - [`environments/dev`](./environments/dev/), [`staging`](./environments/staging/),
    [`prod`](./environments/prod/) — isolated roots.
  - [`.github/workflows/plan.yaml`](./.github/workflows/plan.yaml) and
    [`apply.yaml`](./.github/workflows/apply.yaml) — governance skeletons.
  - [`drift-check.sh`](./drift-check.sh) — read-only drift detection.

> **Cost note:** Uses only the `random` and `local` providers — **zero cloud spend.**
> The GCS backend blocks in the environment files are commented references for
> production. The workflow YAML is inert here (GitHub only runs workflows at the repo
> root).

## Steps

1. **Read the structure.** Note the two halves: `modules/bucket` (the *how*, shared)
   and `environments/*` (the *what*, isolated). Each environment calls the **same**
   module with different inputs — `dev` disables versioning, `staging`/`prod` enable
   it.

2. **Apply dev.** Each environment is its own root with its own state:

   ```bash
   cd 05-infrastructure-as-code/07-iac-patterns-for-platform-teams/lab/environments/dev
   terraform init
   terraform apply -auto-approve
   cat generated/dev-assets.bucket     # versioning=false
   ```

3. **Promote to staging, then prod.** The *same* module, applied to the next
   environment — this is promotion:

   ```bash
   cd ../staging && terraform init && terraform apply -auto-approve
   cd ../prod    && terraform init && terraform apply -auto-approve
   cat generated/prod-assets.bucket    # versioning=true
   ```

   Notice each environment produced its **own** state file
   (`environments/*/terraform.tfstate`). They cannot see or touch each other — that's
   blast-radius isolation.

4. **Prove isolation.** Run a destroy in `dev` and confirm `prod` is untouched:

   ```bash
   cd ../dev && terraform destroy -auto-approve
   cd ../prod && terraform plan        # "No changes." — prod is unaffected
   ```

5. **Run drift detection.** From the lab root, run the read-only watchdog:

   ```bash
   cd ../..          # back to lab/
   bash drift-check.sh ; echo "script exit: $?"
   ```

   With prod applied and unchanged, prod reports **no drift**; dev (which you
   destroyed) reports **DRIFT DETECTED** because its code says a bucket should exist
   but reality (state) says it doesn't. Exit code `1` signals "action needed".

6. **Simulate reconciliation.** Re-apply dev (the deliberate, reviewed fix) and re-run
   the drift check — all environments should now be clean:

   ```bash
   cd environments/dev && terraform apply -auto-approve && cd ../..
   bash drift-check.sh ; echo "script exit: $?"
   ```

7. **Read the governance skeletons.** Open
   [`.github/workflows/plan.yaml`](./.github/workflows/plan.yaml) (plan on PR) and
   [`apply.yaml`](./.github/workflows/apply.yaml) (apply on merge). Note
   `max-parallel: 1` enforcing ordered promotion and `id-token: write` for keyless
   cloud auth — humans never hold prod apply credentials.

## Expected result

- `dev`, `staging`, and `prod` each apply independently with their own state file.
- Destroying `dev` leaves `prod` with **"No changes"** — isolation proven.
- `drift-check.sh` reports per-environment status and a non-zero exit when any
  environment has drift or errors.
- After reconciling, the drift check is clean (exit `0`).

## Cleanup

> Always tear down every environment you applied.

```bash
cd 05-infrastructure-as-code/07-iac-patterns-for-platform-teams/lab
for e in dev staging prod; do (cd "environments/$e" && terraform destroy -auto-approve); done
find environments -maxdepth 2 -type d -name generated -exec rm -rf {} +
find environments -maxdepth 2 \( -name ".terraform" -o -name ".terraform.lock.hcl" -o -name "terraform.tfstate*" \) -exec rm -rf {} +
```

## Reflection

- You destroyed `dev` and `prod` didn't flinch. Which design decision made that
  guarantee, and what would have happened with a single shared state for all three?
- The drift check only *reports*; it never auto-applies. Why is "alert and reconcile
  via PR" safer than "automatically fix drift" for a production environment?
- `dev` sets `versioning = false` while `prod` sets `true`, but both use the same
  module. How does this show the right balance between DRY (shared module) and
  isolation (separate, independently-promoted environments)?

## Stretch goals (optional)

- Add a `modules/bucket` version bump: introduce a new optional input (e.g.
  `retention_days`), default it safely, and "promote" it by setting it in `dev` only,
  then `staging`, then `prod`.
- Wire the drift check into a scheduled GitHub Actions workflow skeleton
  (`on: schedule`) alongside `plan.yaml`.
- Split state further: add a `network` component per environment (a second module)
  and show that an app-infra mistake can't touch the network state.
