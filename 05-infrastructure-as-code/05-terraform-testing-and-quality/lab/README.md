# Lab — Test and Scan a Module (Local & Free)

> You'll run a module up the full quality ladder: **format & validate**, a **static
> security scan**, a **policy-as-code** check against the plan, and a **Go Terratest**
> that applies the module for real, asserts on its output, and destroys it. The
> module uses only free providers, so the whole lab costs nothing.

**Estimated time:** ~60–75 minutes
**Type:** Build / debug
**Deliverable:** A passing `go test` run against the module and a Conftest policy
result, plus a fixed security finding (stretch).

## Objectives

- Enforce formatting and validity with `terraform fmt -check` and `validate`.
- Scan Terraform statically with **tfsec** (or Checkov).
- Enforce an org rule on the **plan** with **Conftest/OPA**.
- Run a **Terratest** that applies → asserts → destroys automatically.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) or
  [OpenTofu](https://opentofu.org/docs/intro/install/).
- [Go](https://go.dev/dl/) 1.22+ for the Terratest step.
- Optional but recommended: [tfsec](https://github.com/aquasecurity/tfsec) (or
  [Checkov](https://www.checkov.io/)) and [Conftest](https://www.conftest.dev/).
- Starter files in this folder:
  - [`module/`](./module/) — the module under test (free `random`/`local` providers).
  - [`test/service_test.go`](./test/service_test.go) and [`test/go.mod`](./test/go.mod).
  - [`policy/naming.rego`](./policy/naming.rego) — the plan policy.
  - [`insecure-example/main.tf`](./insecure-example/main.tf) — scan-only, never
    applied.

> **Cost note:** The module under test and Terratest use only local providers —
> **zero cloud spend.** `insecure-example/` is scanned *statically* (no `init`, no
> `apply`, no credentials) purely so the scanner has something to flag.

## Steps

1. **Format and validate.** The cheapest gate first:

   ```bash
   cd 05-infrastructure-as-code/05-terraform-testing-and-quality/lab/module
   terraform fmt -check -diff      # exits non-zero if not canonically formatted
   terraform init
   terraform validate              # "Success! The configuration is valid."
   ```

2. **Static security scan.** Point a scanner at the deliberately insecure example and
   read the findings (install tfsec or Checkov if you haven't):

   ```bash
   cd ../insecure-example
   tfsec .            # flags the 0.0.0.0/0 ingress and the unencrypted bucket
   # or:
   checkov -d .
   ```

   Note it needs no cloud account — scanning is static. (Scanning the `module/` dir
   will find little, because local files aren't a cloud attack surface — that's the
   point of having a cloud example to scan.)

3. **Policy as code against the plan.** Generate a machine-readable plan and test it
   with your Rego policy:

   ```bash
   cd ../module
   terraform plan -out=tfplan
   terraform show -json tfplan > plan.json
   conftest test plan.json --policy ../policy
   ```

   It should **pass** — the module writes under `generated/`. Now break the rule:
   temporarily change the `filename` in [`module/main.tf`](./module/main.tf) to drop
   the `generated/` prefix, re-plan, and re-test. Conftest should **deny** with your
   message. Revert the change afterward.

4. **Integration test with Terratest.** Run the Go test, which applies the module,
   asserts on its real output, and tears it down — pass or fail:

   ```bash
   cd ../test
   go mod tidy      # downloads Terratest + testify (needs internet, one-time)
   go test -v -timeout 10m
   ```

   Watch the log: Terratest runs `init` and `apply`, reads the `config_path` output,
   asserts the file exists under `generated/payments.conf`, then runs `destroy`.

5. **Make a test fail on purpose.** Change the assertion in
   [`test/service_test.go`](./test/service_test.go) (e.g. expect
   `generated/orders.conf`) and re-run. Observe that `destroy` **still runs** thanks
   to `defer` — a failed test never leaks resources. Revert the change.

## Expected result

- `terraform fmt -check` and `validate` pass on `module/`.
- The scanner reports findings on `insecure-example/` (open ingress, unencrypted
  bucket).
- `conftest test` **passes** for the compliant module and **denies** when you break
  the `generated/` rule.
- `go test` reports `PASS`, and the logs show an automatic `destroy` at the end.

## Cleanup

> The Terratest already destroys what it creates. Remove local working files.

```bash
cd 05-infrastructure-as-code/05-terraform-testing-and-quality/lab
rm -rf module/.terraform module/.terraform.lock.hcl module/terraform.tfstate* \
       module/tfplan module/plan.json module/generated
```

## Reflection

- You tested the module's **contract** (inputs → outputs + the file it creates), not
  which specific resources it used internally. Why does that make the module safe to
  refactor later (e.g. swapping local files for a real cluster)?
- The policy ran against `plan.json`, not the `.tf` files. What could a text-only
  check of the HCL miss that the plan reveals?
- `defer terraform.Destroy` ran even when the test failed. What would your CI bill
  (and your cloud account) look like after a week without that one line?

## Stretch goals (optional)

- Fix the findings in `insecure-example/`: restrict the ingress CIDR and add an
  `aws_s3_bucket_server_side_encryption_configuration`. Re-scan until clean.
- Add a second Rego rule (e.g. "content must include a `name=` line") and a Conftest
  test for it.
- Add a GitHub Actions workflow that runs `fmt -check`, `validate`, the scan, and
  `conftest` on PR — foreshadowing Module 05.7 and
  [Phase 5 · CI/CD](../../../06-cicd-for-platform-teams/).
