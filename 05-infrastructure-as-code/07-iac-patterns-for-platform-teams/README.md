# Module 05.7 — IaC Patterns for Platform Teams

> You now know Terraform, state, modules, testing, and Crossplane. This final module
> assembles them into the **patterns a platform team runs in production**: a
> mono-repo structure, environment promotion (dev → staging → prod), blast-radius
> isolation, governance (PR-only, no console changes), scheduled **drift detection**,
> deliberate **module versioning**, and automated **bootstrapping** of new
> environments.

**Estimated effort:** ~2 hours (theory + lab)
**You'll need:** Modules [05.2](../02-terraform-fundamentals/)–[05.5](../05-terraform-testing-and-quality/). The lab is local and free (`terraform plan` + scripts).

## Learning objectives

By the end of this module you will be able to:

- Structure an IaC **mono-repo** with reusable modules and per-environment roots.
- Apply **environment promotion** so a change proven in dev reaches prod safely.
- Isolate **blast radius** with separate state per environment and per component.
- Enforce **governance**: PR-only changes, plan-on-PR/apply-on-merge, no manual
  console edits.
- Run **scheduled drift detection** and manage **module versioning** and
  **bootstrapping**.

---

## 1. Concept

### The reference layout: modules + environments

The pattern almost every mature Terraform estate converges on separates *reusable
building blocks* from *per-environment composition*:

```text
IaC mono-repo
├── modules/            ← reusable, versioned modules (the paved road)
│   ├── vpc/
│   ├── gke-cluster/
│   └── gcs-bucket/
├── environments/
│   ├── dev/            ← calls modules with dev vars; its OWN state
│   ├── staging/        ← calls modules with staging vars; its OWN state
│   └── prod/           ← calls modules with prod vars; its OWN state
└── .github/workflows/
    ├── plan.yaml       ← runs on PR (plan + checks)
    └── apply.yaml      ← runs on merge to main (apply)
```

Modules hold the *how*; environments hold the *what* (which modules, which inputs).
Each environment is a separate root module with its **own state** — the key to blast
radius (below).

### DRY IaC: when to abstract, when not to

DRY (don't repeat yourself) is a tool, not a religion. **Abstract into a module when
the same shape recurs with a small interface; tolerate repetition when forcing DRY
would couple things that should vary independently.** Over-DRYing environments into
one clever parameterized config is how a single change takes down dev *and* prod at
once. A little duplication across `environments/*` is often *safer* than a brittle
abstraction — the duplication is a blast-radius boundary.

### Environment promotion

A change should prove itself in low-risk environments before reaching prod:

```text
author change ─▶ apply to DEV ─▶ observe ─▶ promote to STAGING ─▶ observe ─▶ PROD
                  (cheap, safe)              (prod-like)                   (guarded)
```

Promotion is usually one of two styles:

- **Same code, different inputs:** identical module calls across environments, only
  variable values differ (region, sizes, counts). Promotion = apply the same code to
  the next environment.
- **Versioned module promotion:** environments pin module *versions*; you bump dev to
  `v1.5.0`, verify, then bump staging, then prod. Promotion = moving a version pin.

### Blast radius management

**Blast radius** is how much a single mistake can destroy. You control it through
**state isolation**:

- **Per environment:** separate state for dev/staging/prod so a bad `dev` apply
  *cannot address* prod resources.
- **Per component:** separate state for high-risk, slow-moving layers (networking,
  IAM, the cluster) from fast-moving ones (app infra). A mistake in app infra can't
  destroy the VPC.

```text
one giant state                      isolated states
───────────────                      ───────────────
all envs + all layers in one   vs.   dev/ stg/ prod/  ×  network/ data/ app/
  → one typo can nuke prod            → a typo is contained to one small state
  → slow plans, scary applies         → fast plans, bounded applies
```

### Governance: the pipeline is the only door

Governance turns "please don't click in the console" into an enforced control:

- **PR-only changes.** All IaC changes arrive as pull requests.
- **Plan on PR, apply on merge.** CI posts the plan for review; merge triggers apply
  of that reviewed plan. Humans hold **no** prod apply credentials.
- **No manual console changes.** Enforced culturally *and* detected automatically
  (drift detection, below). The console is read-only.
- **Required reviews + policy gates.** fmt/validate/scan/policy (Module 05.5) all
  block merge.

### Drift detection

Even with governance, drift happens — an incident, another tool, a rogue click. A
**scheduled drift-detection pipeline** runs a read-only plan on a timer and alerts
when reality diverges from code:

```bash
# nightly, per environment:
terraform plan -detailed-exitcode
# exit 0 = no drift, 2 = drift detected (alert!), 1 = error
```

`-detailed-exitcode` is the magic: exit `2` means "changes pending" (drift), which you
turn into an alert and a ticket to reconcile — deliberately, via PR, not a panicked
apply.

### Module versioning and bootstrapping

- **Version modules; pin consumers.** Tag module releases and pin each environment to
  a version. Upgrade dev first, promote deliberately. Never let `main` of a module
  silently change prod.
- **Bootstrapping** is the automation that stands up a *new* environment from near-
  nothing: create the project/account, the state backend bucket, baseline IAM, then
  apply the environment root. A mature platform can go from "new team needs an
  environment" to a running, governed environment with minimal manual steps — the
  ultimate paved road.

---

## 2. Why it matters for platform engineering

- **This is the platform team's operating model.** Everything above — repo layout,
  promotion, isolation, governance, drift, versioning — *is* how a platform team runs
  infrastructure safely at scale. The earlier modules were the vocabulary; this is the
  sentence.
- **Blast radius is risk management.** The single highest-leverage decision you make
  is how you split state. Get it right and mistakes are survivable; get it wrong and a
  typo is an outage.
- **Governance is what makes "reproducible and auditable" true.** Without PR-only +
  drift detection, IaC quietly degrades back into hand-managed infrastructure.
- **Promotion + versioning are how you change safely.** They let you move fast on dev
  without betting prod on every change.

## 3. Mental model

**Modules are shared and versioned; environments are isolated and promoted; the
pipeline is the only door; a watchdog checks for drift.**

```text
        ┌─────────────── modules/ (versioned paved road, shared) ───────────────┐
        │   vpc @v1.4   gke @v2.1   bucket @v1.0   ...                           │
        └───────────────┬───────────────┬───────────────┬───────────────────────┘
                 pin ▼          pin ▼          pin ▼
   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐     each env:
   │ environments │   │ environments │   │ environments │      - own state
   │   /dev       │──▶│   /staging   │──▶│   /prod      │      - own backend
   └──────────────┘   └──────────────┘   └──────────────┘      - promoted in order
        ▲  promote          ▲  promote          ▲
        └─── PR ─▶ plan-on-PR ─▶ apply-on-merge (the ONLY door) ───┘
                              ⟳ nightly drift detection alerts if reality ≠ code
```

Rules to keep:

- **Share the building blocks; isolate the deployments.**
- **One door to prod: the reviewed pipeline.**
- **Trust, but verify — on a schedule.** (Drift detection.)

## 4. Minimal implementation

You can see the whole operating model with `plan` alone — no apply, no cost. A
drift-detection check is just `plan` with a meaningful exit code:

```bash
#!/usr/bin/env bash
# drift-check.sh — alert if reality has drifted from code (read-only).
set -euo pipefail
for env in dev staging prod; do
  echo "== $env =="
  terraform -chdir="environments/$env" init -input=false -backend=false >/dev/null
  if terraform -chdir="environments/$env" plan -detailed-exitcode -lock=false >/dev/null 2>&1; then
    echo "  no drift"
  else
    code=$?
    [[ $code -eq 2 ]] && echo "  DRIFT DETECTED — open a reconciliation PR" || echo "  plan error"
  fi
done
```

And the two-workflow governance skeleton — plan on PR, apply on merge — is the entire
"one door" pattern:

```yaml
# .github/workflows/plan.yaml (on: pull_request)  → terraform plan, post for review
# .github/workflows/apply.yaml (on: push to main) → terraform apply the reviewed plan
```

That's the operating model in miniature: isolated environments, a read-only drift
watchdog, and a pipeline that is the only path to prod. The lab assembles these into a
real repo structure.

## 5. Hands-on lab

You'll scaffold a complete IaC **mono-repo** — reusable modules plus isolated
`dev`/`staging`/`prod` environments with their own state — wire up **plan-on-PR /
apply-on-merge** workflow skeletons, and write a **drift-detection** script that uses
`plan -detailed-exitcode`. It all runs locally with `plan` and free providers, so
there's no cost.

➡️ **[Start the lab: Build a platform IaC mono-repo](./lab/README.md)**

## 6. Production considerations

- **Right-size your state split.** Too coarse = big blast radius and slow plans; too
  fine = painful cross-state wiring and sprawl. Split by environment always, and by
  component where risk or change-rate differs sharply.
- **Make the pipeline the only credential holder.** Use OIDC/workload identity so CI
  authenticates to the cloud without long-lived keys, and no human has standing prod
  apply rights.
- **Drift detection must create action, not noise.** Route exit-code-2 to a ticket/
  alert with an owner, not a channel everyone mutes. Reconcile via PR.
- **Promote by version, test at each stage.** Pin module versions per environment;
  run the Module 05.5 checks at every promotion; never skip straight to prod.
- **Automate bootstrapping, but review it.** New-environment automation is powerful
  and dangerous — it creates accounts and IAM. Gate it behind review and least
  privilege.
- **Document the operating model.** The repo README should state the rules: PR-only,
  how to promote, how drift is handled. Governance that isn't written down erodes.

## 7. Common mistakes

- **One state to rule them all.** Everything in a single state/workspace. *Why:* it's
  simplest at first. *Fix:* isolate per environment (and risky components) before the
  blast radius bites.
- **Over-DRY environments.** A single hyper-parameterized config for all envs so one
  change hits prod instantly. *Fix:* accept some duplication across `environments/*`;
  it's a safety boundary.
- **Manual "just this once" console changes.** They create silent drift and break
  reproducibility. *Fix:* PR-only culture + automated drift detection to catch
  slips.
- **Floating module references.** Environments tracking a module's `main`. *Why:*
  "always latest." *Fix:* pin versions; promote upgrades deliberately.
- **Drift detection that nobody acts on.** A nightly job whose alerts are ignored.
  *Fix:* make each drift a ticket with an owner and an SLA; reconcile via PR.
- **Humans with prod apply creds "for emergencies."** The emergency path becomes the
  normal path. *Fix:* break-glass with audit, not standing access.

## 8. Assessment

**Knowledge checks**

1. Why does each environment get its own state, and what does that protect?
2. What does `terraform plan -detailed-exitcode` return on drift, and how do you use
   it?
3. Give one case where *duplicating* config across environments is better than a DRY
   abstraction.
4. What does "plan on PR, apply on merge" enforce beyond convenience?
5. How do you promote a module upgrade from dev to prod safely?

**Concept exercise**

> Explain "blast radius" and how you'd limit it **without using the words "state,"
> "Terraform," or "workspace."** Use an analogy (e.g. bulkheads in a ship).

**Architecture / trade-off exercise**

> You inherit a single Terraform configuration with one state file managing the VPC,
> the GKE cluster, IAM, and every team's app infrastructure for *all three*
> environments. A recent `apply` meant for dev nearly destroyed a prod subnet. Design
> the target structure: how would you split state (by environment and/or component),
> how would changes flow dev → prod, and what two governance controls would you add
> first? Name one risk your new split introduces and how you'd mitigate it.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** So a mistake in one environment cannot address or destroy another's
  resources. It bounds blast radius and also speeds up plans (smaller state).
- **Q2:** Exit `0` = no changes, `2` = changes pending (drift), `1` = error. Run it on
  a schedule; treat exit `2` as a drift alert → reconciliation PR (not an auto-apply).
- **Q3:** When environments must vary independently or when a shared abstraction would
  couple them so a single change hits all envs at once. The duplication is a
  blast-radius boundary; e.g. keeping `environments/prod` separate so a dev change
  can't touch it.
- **Q4:** It makes the reviewed pipeline the only path to prod: every change is
  planned, reviewed, scanned, policy-checked, applied from CI (not laptops), and
  audited — preventing un-reviewed changes and drift.
- **Q5:** Pin module versions per environment; bump dev to the new version, run checks
  and observe; then promote the pin to staging, verify; then prod. Each step is a
  reviewed PR.
- **Architecture:** Split state at least by environment (dev/staging/prod each own
  backend) and by component within an environment (network/IAM separate from app
  infra), so the slow-moving, high-risk layers are isolated from fast-moving app
  changes. Changes flow as PRs: apply to dev, observe, promote to staging, then prod,
  via plan-on-PR/apply-on-merge. First two governance controls: (1) remove human prod
  apply credentials — pipeline-only via OIDC; (2) scheduled drift detection with
  owned alerts. New risk: more states mean cross-state references (e.g. app infra
  needs the VPC id) — mitigate with `terraform_remote_state` data sources or a
  published outputs contract, and keep the split only as fine as the risk warrants.

</details>

## 9. Further reading

- HashiCorp — [Separate state / multiple environments guidance](https://developer.hashicorp.com/terraform/language/state/remote)
  and [Recommended practices](https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices)
- Gruntwork — [How to manage Terraform state and environments](https://blog.gruntwork.io/how-to-manage-terraform-state-28f5697e68fa)
- HashiCorp — [`plan -detailed-exitcode`](https://developer.hashicorp.com/terraform/cli/commands/plan#detailed-exitcode)
- Google Cloud — [Best practices for Terraform (structure & environments)](https://cloud.google.com/docs/terraform/best-practices-for-terraform)
- HashiCorp — [GitHub Actions for Terraform (plan on PR, apply on merge)](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- OpenTofu — [State and drift](https://opentofu.org/docs/language/state/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 05.6 — Crossplane](../06-crossplane/) · _Next:_ [Phase 5 — CI/CD for Platform Teams →](../../06-cicd-for-platform-teams/)
