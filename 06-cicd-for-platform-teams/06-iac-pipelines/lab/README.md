# Lab — A Terraform plan-on-PR / apply-on-merge pipeline

> You'll run the `plan → review → apply` loop locally against a free `local`-provider
> config, deliberately cause **drift** and catch it with `-detailed-exitcode`, then
> validate a full `terraform.yml` (plan-on-PR with a PR comment, auto-apply to dev, gated
> apply to production, nightly drift) with `actionlint`. Local and free; running it on
> GitHub against a real backend is an optional, marked extension.

**Estimated time:** ~50–70 minutes
**Type:** build
**Deliverable:** A local `plan`/`apply`/drift run you can explain, and a validated
[`terraform.yml`](./terraform.yml) pipeline.

## Objectives

- Run `init → fmt → validate → plan → apply` and treat the plan as the review artifact.
- Apply the **saved** plan so what runs is what you reviewed.
- Cause and detect **drift** via `terraform plan -detailed-exitcode`.
- Validate an IaC pipeline and map each job to a concept (gates, OIDC, locking).

## Prerequisites

- The lesson [`../README.md`](../README.md) and
  [Phase 4 · Infrastructure as Code](../../../05-infrastructure-as-code/).
- [Terraform](https://developer.hashicorp.com/terraform/install) installed
  (`terraform version`); see
  [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md).
- [`actionlint`](https://github.com/rhysd/actionlint) installed.
- Starter files here: [`main.tf`](./main.tf) (free `local` provider — no cloud) and
  [`terraform.yml`](./terraform.yml). No cloud account is needed for Steps 1–6.

## Steps

1. **Validate the pipeline.**

   ```bash
   actionlint terraform.yml
   ```

   Expect exit 0. Open [`terraform.yml`](./terraform.yml) and map each job: `plan` (PR
   only, read-only, comments the diff), `apply-dev` (auto on merge), `apply-prod` (gated by
   the `production` environment), `drift` (scheduled). Note the per-job `id-token: write`
   (keyless) and `concurrency` with `cancel-in-progress: false`.

2. **Initialize and check the config.**

   ```bash
   terraform init -input=false
   terraform fmt -check
   terraform validate
   ```

   `init` downloads the `local` provider (no cloud, no credentials). `fmt`/`validate` are
   your fast, decisive gates.

3. **Plan, review, then apply the saved plan.**

   ```bash
   terraform plan -out tfplan        # the DIFF a reviewer would read on the PR
   terraform apply tfplan            # apply EXACTLY what you reviewed — no re-plan
   cat greeting.txt                  # the resource this config manages
   ```

   Applying the saved `tfplan` (not a fresh plan) is the production-safe habit: what runs
   is what was approved.

4. **Cause drift and catch it.**

   ```bash
   echo "tampered out of band" > greeting.txt    # simulate a console change
   terraform plan -detailed-exitcode             # reality no longer matches state
   echo "drift exit: $?"                         # 2 = DRIFT (the nightly job alerts)
   ```

   Exit code `2` is what the scheduled `drift` job turns into a red build and an alert —
   fail loud, never silent (Module 06.1).

5. **Reconcile and confirm it's quiet.**

   ```bash
   terraform apply -auto-approve        # bring reality back to code
   terraform plan -detailed-exitcode
   echo "reconciled exit: $?"           # 0 = in sync (quiet)
   ```

6. **Reason about security and gates (written).**

   In a few sentences: why does the `plan` job get a *read-only* role while only `apply`
   gets *write*? What stops two merges from corrupting state here? Where would a required
   reviewer pause the `production` apply, and who would you make the reviewer?

7. **(Optional, cloud/GitHub) Run it for real.**

   > **Cost & accounts note.** Running `terraform.yml` end to end needs a GitHub repo and,
   > for real infrastructure, a cloud account and a **remote state backend** (S3+DynamoDB,
   > GCS, or TF Cloud) plus OIDC roles. Managed infrastructure can incur spend — stay on
   > free tiers, scope least-privilege roles, and run the cleanup. You can skip this and
   > still complete the lab; the deliverable is the local loop plus the validated pipeline.

   Put `main.tf` and `terraform.yml` (as `.github/workflows/terraform.yml`) in a repo,
   configure a remote backend and the commented-out keyless auth step with a **read-only**
   role for `plan` and a **write** role for `apply`, add a required reviewer to the
   `production` environment, and open a PR to watch the plan comment appear.

## Expected result

- `actionlint terraform.yml` exits 0.
- `terraform apply tfplan` creates `greeting.txt`.
- After tampering, `plan -detailed-exitcode` exits `2`; after reconciling, it exits `0`.
- You can explain read-only-plan vs write-apply, locking/concurrency, and the prod gate.

## Cleanup

> The `local` provider creates only local files, but remove the Terraform working files.

```bash
terraform destroy -auto-approve 2>/dev/null || true
rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup tfplan greeting.txt
# If you did Step 7, tear down any cloud resources and delete the scratch repo.
```

## Reflection

- You applied the *saved* plan rather than re-planning at apply time. What race does that
  prevent, and why does it matter more for infrastructure than for an app deploy?
- Drift showed up as a non-empty plan. Would you always auto-reconcile it, or are there
  cases where the right move is to update the code to match reality?
- The plan job can run code from a fork PR. Why is giving it write credentials one of the
  most dangerous mistakes in an IaC pipeline?

## Stretch goals (optional)

- Add a `tfsec` run locally (`tfsec .`) and introduce a deliberately insecure resource to
  watch the gate fire.
- Change `main.tf` to manage two files and observe how the plan diff communicates a
  multi-resource change to a reviewer.
- Sketch (in prose) how this same `plan → review → apply` loop becomes Project 2's
  promotion-by-PR into a config repo once a GitOps controller (Phase 6) reconciles the
  merged result.
