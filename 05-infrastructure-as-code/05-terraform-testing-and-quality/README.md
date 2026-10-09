# Module 05.5 — Terraform Testing and Quality

> Unreviewed, untested infrastructure code is a liability waiting to cause an
> outage or a breach. This module covers the quality ladder every serious IaC
> codebase climbs: **formatting and validation**, **static security scanning**
> (tfsec/Checkov), **policy as code** (OPA/Conftest), **integration tests**
> (Terratest), and the **PR workflow** — plan on PR, apply on merge — that enforces
> all of it.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 05.4](../04-terraform-modules/), Terraform/OpenTofu, and (optional but recommended) Docker, Go, and one of tfsec/Checkov/Conftest. The lab runs locally and free.

## Learning objectives

By the end of this module you will be able to:

- Use `terraform fmt` and `terraform validate` as the first quality gate.
- Run **static security scanners** (tfsec, Checkov) against Terraform and read their
  findings.
- Write and apply **policy as code** with OPA/Conftest against a Terraform plan.
- Write a **Terratest** integration test in Go that applies, asserts, and destroys.
- Design the **PR check workflow**: plan on PR, enforced apply on merge.

---

## 1. Concept

### A ladder of increasing confidence

Testing infrastructure isn't one thing; it's a ladder, cheap and fast at the bottom,
slower and higher-fidelity at the top. Run the cheap checks on every change; reserve
the expensive ones where they earn their keep.

```text
  slow / high-fidelity
    ▲   Terratest        — apply real resources, assert, destroy (integration)
    │   Policy (OPA)     — org rules on the PLAN (no "public buckets", required tags)
    │   Security scan    — tfsec / Checkov: known misconfigurations (static)
    │   validate         — internal consistency, provider schema
    ▼   fmt              — canonical formatting (style)
  fast / cheap
```

### Formatting and validation: the free wins

- **`terraform fmt`** rewrites files to canonical style. Enforced with
  `fmt -check` in CI, it ends every formatting debate.
- **`terraform validate`** checks a configuration is internally consistent and
  matches provider schemas — undeclared variables, wrong types, bad references —
  without touching real infrastructure.

These catch a surprising share of mistakes in milliseconds. They are the floor.

### Static security scanning

**tfsec** and **Checkov** scan Terraform *statically* (no apply) for known insecure
patterns: a storage bucket open to the public, an unencrypted disk, an over-broad
IAM binding, a security group open to `0.0.0.0/0`. They ship hundreds of built-in
rules mapped to benchmarks (CIS, etc.).

```bash
tfsec .                 # scans the current module, prints findings by severity
checkov -d .            # same idea, different rule set and output
```

They're fast, run in CI on every PR, and turn "we'll review security later" into a
blocking gate. Neither is complete — they catch *known* misconfigurations — so pair
them with policy and human review.

### Policy as code (OPA / Conftest)

Scanners enforce *generic* best practice. **Policy as code** enforces *your
organization's* rules: "every resource must have an `owner` tag," "no resource
outside approved regions," "prod databases must have deletion protection." You write
policies in **Rego** and evaluate them with **Conftest** (built on **Open Policy
Agent**) against the JSON form of a Terraform **plan**.

```bash
terraform plan -out=tfplan
terraform show -json tfplan > plan.json
conftest test plan.json          # evaluates your Rego policies against the plan
```

```rego
# policy/deny_public.rego — deny any bucket with public access
package main

import rego.v1

deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "google_storage_bucket"
  resource.change.after.public_access_prevention == "inherited"
  msg := sprintf("bucket %q must set public_access_prevention = enforced", [resource.address])
}
```

Testing the **plan** (not the code text) means you check what Terraform *will
actually do*, after variables and defaults are resolved.

### Terratest: real integration tests

**Terratest** is a Go library that drives Terraform programmatically: it runs
`init`/`apply`, inspects outputs and real resources, asserts, and then `destroy`s —
even if the test fails (via `defer`). It's how you verify a module *actually
produces working infrastructure*, not just valid HCL.

```go
func TestServiceModule(t *testing.T) {
    opts := &terraform.Options{TerraformDir: "../modules/service"}
    defer terraform.Destroy(t, opts)          // always clean up
    terraform.InitAndApply(t, opts)           // provision for real

    path := terraform.Output(t, opts, "config_path")
    assert.FileExists(t, path)                // assert the real result
}
```

Terratest is slower and costs real resources (so target cheap/local resources in CI
where possible), but it's the only layer that proves end-to-end behavior.

### Contract testing: interface, not implementation

Test a module's **interface** — given these inputs, I get these outputs and these
externally observable properties — not its internal resource wiring. That way the
module can be refactored freely as long as the contract holds, and your tests don't
break on every internal change.

### The PR workflow that enforces it all

Quality only matters if it's enforced. The standard platform pattern:

```text
open PR ─▶ CI runs: fmt-check · validate · tfsec/checkov · conftest · terraform plan
         └─ plan posted as a PR comment for human review
merge   ─▶ CI runs: terraform apply (of the reviewed plan)   ← only path to prod
```

Humans never apply from laptops. The pipeline is the only way to change
infrastructure, which makes every change reviewed, scanned, policy-checked, and
auditable.

---

## 2. Why it matters for platform engineering

- **Modules are shared blast radius.** A bug in a platform module ships to every
  consumer. Tests are what let you refactor and upgrade shared modules with
  confidence.
- **Security and compliance become structural.** Scanning + policy-as-code bake "no
  public buckets, everything tagged, approved regions only" into the pipeline — not
  into a wiki nobody reads.
- **The plan-on-PR gate is governance.** It's the concrete mechanism behind "no
  manual console changes; every change reviewed" (Module 05.7).
- **Fast feedback = adoption.** If the paved-road module has tests and scans, teams
  trust it and stay on it. Quality is part of developer experience.

## 3. Mental model

**Shift left: catch each class of problem at the cheapest possible stage.**

```text
   cost to catch a problem
        ▲
   prod │                                   ● incident (worst, most expensive)
        │                         ● manual review
        │               ● Terratest (apply)
        │        ● policy / security scan
        │   ● validate
   cheap│ ● fmt
        └──────────────────────────────────────────▶ earlier = cheaper
```

Rules to keep:

- **Every layer catches what cheaper layers can't** — don't skip, stack them.
- **Test the plan and the real outputs**, not the HCL text.
- **If it isn't enforced in CI, it doesn't exist.**

## 4. Minimal implementation

The cheapest meaningful quality gate is three commands and a tiny policy — no cloud
needed. Given any module:

```bash
terraform fmt -check -recursive        # fail if not canonically formatted
terraform validate                     # fail on inconsistency/bad types
tfsec .                                # fail on known-insecure patterns
```

Add a one-rule policy on the plan to enforce an org convention — here, "every
`local_file` must live under a `generated/` directory" (a stand-in for a real rule
like "every bucket must be private"):

```rego
# policy/naming.rego
package main

import rego.v1

deny contains msg if {
  rc := input.resource_changes[_]
  rc.type == "local_file"
  not startswith(rc.change.after.filename, "./generated/")
  msg := sprintf("%s: files must be created under ./generated/", [rc.address])
}
```

```bash
terraform plan -out=tfplan && terraform show -json tfplan > plan.json
conftest test plan.json
```

That's the whole idea: fast static checks plus a plan-level policy, both runnable
locally and both suitable as blocking CI gates. Terratest (the lab) adds the
apply-and-assert layer on top.

## 5. Hands-on lab

You'll put a small module through the full quality ladder **locally and free**:
`fmt`/`validate`, a **tfsec** scan, a **Conftest/OPA** policy against the plan, and a
**Go Terratest** test that applies a local module, asserts on its real output, and
destroys it. A ready Terratest file and policy are provided.

➡️ **[Start the lab: Test and scan a module](./lab/README.md)**

## 6. Production considerations

- **Make checks blocking, not advisory.** A scan that only warns gets ignored. Fail
  the PR on high-severity findings; provide a documented, reviewed exception
  mechanism (e.g. inline ignores with a justification).
- **Keep Terratest costs bounded.** Integration tests apply real resources. Use
  cheap/ephemeral ones, short-lived projects, aggressive `defer destroy`, and run the
  expensive suite on a schedule or label, not every commit.
- **Version your policies.** Rego policies are code too — review, test (OPA has a
  test framework), and roll out changes deliberately so you don't break every PR at
  once.
- **Scan modules *and* compositions.** A module can be clean while a composition
  wires it insecurely. Scan the environment root modules as well.
- **Store and apply the exact plan.** `plan -out=tfplan` on PR, `apply tfplan` on
  merge — so what was reviewed and policy-checked is byte-for-byte what applies.
- **Supply-chain hygiene.** Pin provider and module versions, commit lockfiles, and
  scan third-party modules before adopting them.

## 7. Common mistakes

- **Formatting/linting that only warns.** Non-blocking checks rot. *Fix:*
  `fmt -check` and scanners **fail** the build.
- **Testing the HCL text instead of the plan.** Asserting on source strings misses
  what defaults/variables resolve to. *Fix:* evaluate policy against
  `terraform show -json` of a plan.
- **Terratest with no `defer destroy`.** A failed test leaks real resources and
  cost. *Fix:* `defer terraform.Destroy(...)` is the first line after options.
- **Relying on one scanner as "security done."** tfsec/Checkov catch *known* issues
  only. *Fix:* layer policy-as-code and human review; they're complementary.
- **Applying from laptops "just this once."** Bypasses every gate and creates drift.
  *Fix:* pipeline-only apply; no human has prod apply creds.
- **Giant, slow test suites run on every commit.** People start skipping them. *Fix:*
  fast checks on every PR; heavy Terratest on merge/schedule.

## 8. Assessment

**Knowledge checks**

1. What's the difference between `terraform validate` and a tfsec scan?
2. Why do you evaluate policy against the JSON *plan* rather than the `.tf` files?
3. What does `defer terraform.Destroy` do in a Terratest test, and why is it
   essential?
4. What does "plan on PR, apply on merge" buy you beyond convenience?
5. What is contract testing a module, and why test the interface not the
   implementation?

**Concept exercise**

> Explain how you'd stop a teammate from ever merging a publicly-readable storage
> bucket **without using the words "tfsec," "Checkov," or "scanner."** (Describe the
> control, not the product.)

**Debugging / trade-off exercise**

> Your Terratest suite takes 40 minutes because it provisions a real GKE cluster per
> test, and engineers have started merging with the tests skipped. Diagnose why this
> happened, then propose a layered strategy: what should run on every PR (seconds),
> what on merge, and what on a nightly schedule — and how you'd keep integration-test
> cost and flakiness under control.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** `validate` checks internal consistency and provider-schema correctness
  (does the config make sense?). A tfsec scan checks for known *security*
  misconfigurations (is the config *safe*?). Different questions; both static.
- **Q2:** The plan reflects what Terraform will actually do after variables, defaults,
  and computed values resolve. The raw `.tf` text may not reveal the effective
  settings; the plan does.
- **Q3:** It schedules the destroy to run when the test function returns — pass or
  fail — guaranteeing provisioned resources are cleaned up so tests don't leak cost.
- **Q4:** It makes the pipeline the only path to prod: every change is reviewed via
  its plan, scanned, policy-checked, and auditable; humans don't apply from laptops,
  which prevents drift and un-reviewed changes.
- **Q5:** Asserting that given inputs you get the expected outputs and externally
  observable properties — not which internal resources exist. It lets you refactor
  the module's internals without breaking tests, as long as the contract holds.
- **Debugging:** Tests got slow and expensive, so humans routed around them —
  classic. Layer it: on every PR run fmt/validate/tfsec/conftest and a `plan`
  (seconds, no cost); on merge run a *small* Terratest against cheap/local or a
  single ephemeral resource; run the full real-cluster Terratest nightly or behind a
  label. Bound cost/flakiness with ephemeral projects, `defer destroy`, retries on
  known-eventual-consistency checks, and parallelism caps. Make the fast gates
  blocking so nothing merges unchecked.

</details>

## 9. Further reading

- HashiCorp — [`fmt`](https://developer.hashicorp.com/terraform/cli/commands/fmt)
  and [`validate`](https://developer.hashicorp.com/terraform/cli/commands/validate)
- Aqua Security — [tfsec](https://github.com/aquasecurity/tfsec) (now part of
  [Trivy](https://trivy.dev/))
- [Checkov by Prisma Cloud](https://www.checkov.io/)
- Open Policy Agent — [OPA](https://www.openpolicyagent.org/) and
  [Conftest](https://www.conftest.dev/)
- Gruntwork — [Terratest](https://terratest.gruntwork.io/)
- HashiCorp — [Terraform `test` framework (native tests)](https://developer.hashicorp.com/terraform/language/tests)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 05.4 — Terraform Modules](../04-terraform-modules/) · _Next:_ [Module 05.6 — Crossplane →](../06-crossplane/)
