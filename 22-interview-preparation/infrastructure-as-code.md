# Interview Prep — Infrastructure as Code

> This domain tests whether you treat infrastructure like software: declarative,
> versioned, reviewed, tested, and reproducible. Interviewers probe state, drift,
> secrets, and the trade-off between pipeline-driven tools (Terraform) and
> control-plane tools (Crossplane). Practice explaining *why* state and
> idempotency exist, not just which commands you type.

## Principles

### Q: What is Infrastructure as Code, and why declarative over imperative?

**What they're really asking:** Do you understand the paradigm, not just the tooling?

IaC means defining infrastructure in version-controlled, machine-readable files so
it is created and changed by code review and automation rather than by clicking in a
console. **Declarative** IaC (Terraform, Kubernetes) describes the desired *end
state* and lets the tool compute how to get there; **imperative** scripting lists the
*steps*. Declarative wins because it is **idempotent**, diffable in a pull request,
able to detect **drift**, and composable — whereas imperative scripts are
order-dependent and silently drift from reality.

**Going deeper:** [05.1 · IaC Principles](../05-infrastructure-as-code/01-iac-principles/)

**Red flags:** "IaC is just bash scripts that build servers." Missing declarative desired-state and review.

### Q: What is idempotency, and why does it matter for IaC?

**What they're really asking:** Do you understand safe, repeatable convergence?

Idempotency means applying the same configuration repeatedly converges to the same
result with no additional changes. It is what makes re-runs and continuous
reconciliation **safe**: the tool compares desired state to actual and only acts on
the difference. Without it you cannot re-apply with confidence or recover
deterministically.

**Going deeper:** [05.1 · IaC Principles](../05-infrastructure-as-code/01-iac-principles/)

## Terraform state and workflow

### Q: What is Terraform state and why does it matter?

**What they're really asking:** Do you understand the mapping between config and the real world?

State is Terraform's record mapping the resources in your configuration to the
**real-world object IDs** that back them, plus metadata and a dependency graph.
It matters because:

- `plan` **diffs** desired config against state to decide what to create, update, or destroy.
- It preserves **resource identity**, so Terraform updates rather than recreates.
- It stores outputs and speeds up runs by avoiding a full API refresh.

Risks: state often holds **secrets in plaintext**, so it must be encrypted and
access-controlled. For teams it must be **remote and locked** (S3 plus DynamoDB,
GCS, or Terraform Cloud) to prevent two applies from corrupting it. Never hand-edit
it — use `terraform state mv` and `import`.

**Going deeper:** [05.3 · Terraform State Management](../05-infrastructure-as-code/03-terraform-state-management/)

**Red flags:** Local state committed to Git, no locking, or editing `terraform.tfstate` by hand.

### Q: What is drift, and how does the plan/apply workflow detect it?

**What they're really asking:** Do you know how IaC stays authoritative?

Drift is when real infrastructure diverges from what the code and state say —
usually because someone changed it manually in the console. `terraform plan`
**refreshes** state against the provider and shows the diff; `apply` reconciles
reality back to the declared desired state. Mature teams run `plan` on a schedule in
CI to **detect drift continuously** and alert, rather than discovering it during an
unrelated change.

**Going deeper:** [05.3 · Terraform State Management](../05-infrastructure-as-code/03-terraform-state-management/) and [06.6 · IaC Pipelines](../06-cicd-for-platform-teams/06-iac-pipelines/)

### Q: Terraform workspaces versus separate state files — when do you use each?

**What they're really asking:** Do you know that workspaces are not a strong isolation boundary?

**Workspaces** give you multiple state instances from one configuration and one
backend key — handy for short-lived, *identical* copies of the same stack. **Separate
state files** (distinct directories or backends per environment) give true
**isolation**: independent blast radius, different variables, and separate
permissions. For dev/staging/prod you generally want **separate state**, not
workspaces, because a single misconfigured workspace switch can apply prod changes
to dev or vice versa, and real environments rarely stay identical.

**Going deeper:** [05.3 · Terraform State Management](../05-infrastructure-as-code/03-terraform-state-management/) and [05.7 · IaC Patterns for Platform Teams](../05-infrastructure-as-code/07-iac-patterns-for-platform-teams/)

**Red flags:** Using workspaces as the primary prod/dev boundary and being surprised by cross-environment applies.

### Q: How do you handle secrets in Terraform?

**What they're really asking:** Do you keep secrets out of code and out of plaintext state?

- **Never hardcode** secrets or commit `*.tfvars` containing them.
- Pull secrets at run time from a **secrets manager** (Vault, AWS/GCP Secrets Manager) via data sources, and mark variables `sensitive` so they are redacted in output.
- Remember state stores resolved values **in plaintext**, so **encrypt state** and restrict who can read the backend.
- Prefer **short-lived, dynamic credentials** — OIDC federation from CI to the cloud — over long-lived static keys.

**Going deeper:** [05.3 · Terraform State Management](../05-infrastructure-as-code/03-terraform-state-management/) and [13.4 · Secret Management](../13-security-and-policy-engineering/04-secret-management/)

**Red flags:** Secrets in `tfvars` in Git, or assuming `sensitive = true` encrypts state (it only hides console output).

### Q: How do you structure state to limit blast radius?

**What they're really asking:** Do you design for failure isolation and team ownership?

Split state by **lifecycle and ownership**: networking separate from application
separate from data, per environment and per team. Small, focused states reduce lock
contention, shrink the damage a bad `apply` can do, and let teams own their slice.
Connect states through **remote state data sources** or explicit inputs rather than
one monolithic state for the whole estate.

**Going deeper:** [05.7 · IaC Patterns for Platform Teams](../05-infrastructure-as-code/07-iac-patterns-for-platform-teams/)

## Modules, testing, and control planes

### Q: What makes a good Terraform module for a platform team?

**What they're really asking:** Do you build reusable, opinionated building blocks?

A good module has a **single responsibility**, **sane secure defaults**, a **minimal
set of required inputs**, clear **outputs**, and is **versioned** (registry or tag) and
**documented** with examples. For a platform team it should encode the golden path —
tagging, encryption, logging on by default — so every consumer starts compliant.
Avoid "god modules" that take fifty variables and try to configure everything.

**Going deeper:** [05.4 · Terraform Modules](../05-infrastructure-as-code/04-terraform-modules/) and [05.7 · IaC Patterns for Platform Teams](../05-infrastructure-as-code/07-iac-patterns-for-platform-teams/)

### Q: How do you test IaC?

**What they're really asking:** Do you know the testing pyramid for infrastructure?

Layer it from cheap and fast to slow and thorough:

- **Static** — `terraform fmt`, `validate`, `tflint`, and security scanners (`tfsec`/Checkov) in CI.
- **Policy as code** — OPA/Conftest or Sentinel to enforce rules on the plan (no public buckets, mandatory tags).
- **Plan review** — a `plan` posted to the pull request so humans see the diff before merge.
- **Unit/integration** — `terraform test` or Terratest that spins up **ephemeral** infrastructure in a sandbox, asserts behavior, then **destroys** it.

**Going deeper:** [05.5 · Terraform Testing and Quality](../05-infrastructure-as-code/05-terraform-testing-and-quality/)

**Red flags:** "We apply to prod and see if it works." No static checks, no policy gate, no ephemeral testing.

### Q: What is Crossplane, and when would you choose it over Terraform?

**What they're really asking:** Do you understand control-plane IaC versus pipeline IaC?

Crossplane turns infrastructure provisioning into a **Kubernetes control plane**: you
declare resources as Kubernetes custom resources (Claims and Compositions), and
in-cluster controllers **continuously reconcile** desired versus actual — the same
loop as any Kubernetes controller — so drift is corrected automatically and there is
no separate state file to manage. Terraform is **pipeline-driven** with an explicit
state file and `plan`/`apply`, and has the broadest provider ecosystem and mature
modules.

Choose **Crossplane** when you want continuous reconciliation and a **Kubernetes-native
self-service API** (with RBAC) so app teams can request infrastructure by applying a
Claim, and you want to compose opinionated platform abstractions. Choose **Terraform**
for its ecosystem, one-shot provisioning, and when you do not want to operate a
control plane. Many platforms use both — Terraform for the base estate, Crossplane
for the app-facing self-service layer.

**Going deeper:** [05.6 · Crossplane](../05-infrastructure-as-code/06-crossplane/)

**Red flags:** Framing them as interchangeable, or ignoring that Crossplane means running and operating a control plane.

### Q: What is immutable infrastructure?

**What they're really asking:** Do you know the replace-don't-mutate model?

Immutable infrastructure means you **never patch a running server in place** — you
build a new versioned artifact (an image or container) and **replace** the old one.
Benefits are reproducibility, no accumulated configuration drift, and trivial,
deterministic rollback (deploy the previous image). It is the opposite of mutable
"SSH in and patch" servers, which become unreproducible snowflakes.

**Going deeper:** [05.1 · IaC Principles](../05-infrastructure-as-code/01-iac-principles/) and [02.2 · Dockerfile and Image Building](../02-containerization/02-dockerfile-and-image-building/)
