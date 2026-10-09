# Module 05.2 — Terraform Fundamentals

> Terraform (and its open-source fork, OpenTofu) is the most widely used IaC tool in
> the industry. This module teaches its building blocks — providers, resources, data
> sources, variables, outputs, dependencies, and the `init → plan → apply → destroy`
> loop — and grounds them in the principles from Module 05.1. You'll read real GKE
> code and run a cost-free local project.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 05.1](../01-iac-principles/), [Terraform or OpenTofu](https://developer.hashicorp.com/terraform/install) installed, and Docker running (for the local lab).

## Learning objectives

By the end of this module you will be able to:

- Explain **providers**, **resources**, and **data sources**, and write all three.
- Parameterize configuration with **variables**, **locals**, and **outputs**.
- Reason about **implicit** and **explicit** resource dependencies and the graph
  Terraform builds.
- Run the core workflow: `init`, `plan`, `apply`, `destroy`, `show`, `state list`.
- Use the meta-arguments **`count`**, **`for_each`**, **`depends_on`**, and
  **`lifecycle`**, plus `terraform_data` for local operations.

---

## 1. Concept

### Terraform in one paragraph

Terraform reads `.tf` files written in **HCL** (HashiCorp Configuration Language),
builds a dependency graph of the resources you declared, compares that desired state
to the recorded **state** and the real world, and produces a **plan** of changes.
You review the plan; `apply` enacts it. It is the control loop from Module 05.1, made
industrial. **OpenTofu** is a drop-in open-source fork; nearly everything here
applies identically — swap `terraform` for `tofu`.

### Providers: the plugins that talk to APIs

A **provider** is a plugin that knows how to manage a particular API — Google Cloud,
AWS, Azure, Kubernetes, Docker, GitHub, or local primitives like random values and
files. You declare which providers you need and Terraform downloads them during
`init`.

```hcl
terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
```

### Resources: the things you manage

A **resource** block declares one piece of infrastructure. Its two labels are the
**type** (defined by a provider) and a **local name** (your handle for referencing
it). Here is the real GKE cluster from the outline — production-grade GCP code you'll
read now and run locally in a cheaper form later:

```hcl
resource "google_container_cluster" "platform" {
  name     = "platform-cluster"
  location = var.region

  # Best practice: manage node pools separately, so remove the default one.
  remove_default_node_pool = true
  initial_node_count       = 1

  release_channel {
    channel = "REGULAR"
  }
}

resource "google_container_node_pool" "primary" {
  name       = "primary"
  cluster    = google_container_cluster.platform.name
  location   = var.region
  node_count = var.node_count

  node_config {
    machine_type = "e2-standard-4"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}
```

### Data sources: reading what you don't manage

A **data source** reads information about resources Terraform does *not* manage —
an existing network, the latest image, the current project. It's read-only input to
your configuration.

```hcl
data "google_compute_network" "existing" {
  name = "shared-vpc"
}

# reference it: data.google_compute_network.existing.id
```

### Variables, locals, and outputs

- **Variables** (`variable`) are typed inputs — the knobs a caller sets.
- **Locals** (`locals`) are named expressions computed once and reused — DRY within
  a config.
- **Outputs** (`output`) expose values after apply, for humans or for other modules.

```hcl
variable "region" {
  type        = string
  default     = "europe-west1"
  description = "GCP region for regional resources."
}

locals {
  cluster_name = "platform-${var.environment}"
}

output "cluster_endpoint" {
  value       = google_container_cluster.platform.endpoint
  description = "The cluster API endpoint."
  sensitive   = true
}
```

### Dependencies: implicit and explicit

Terraform doesn't apply resources top-to-bottom. It builds a **dependency graph** and
applies in the correct order, parallelizing where it can. Most dependencies are
**implicit**: when `google_container_node_pool.primary` references
`google_container_cluster.platform.name`, Terraform knows the cluster must exist
first. When there's a hidden ordering it can't infer, you add an **explicit**
`depends_on`.

### The core workflow

```text
terraform init     # download providers, set up the backend
terraform fmt      # canonical formatting
terraform validate # syntax + internal consistency
terraform plan     # show the diff — review this!
terraform apply    # enact the plan
terraform show     # inspect current state in detail
terraform destroy  # tear it all down
```

### Meta-arguments

Meta-arguments work on any resource:

- **`count`** — create N copies, indexed `[0]`, `[1]`, … Good for identical,
  order-numbered resources.
- **`for_each`** — create one per key in a map/set, indexed by key. Preferred when
  instances have stable identities (adding/removing one won't churn the others).
- **`depends_on`** — declare an explicit dependency Terraform can't infer.
- **`lifecycle`** — control behavior: `create_before_destroy`, `prevent_destroy`,
  `ignore_changes`.

```hcl
resource "google_storage_bucket" "env" {
  for_each = toset(["dev", "staging", "prod"])
  name     = "acme-platform-${each.key}"
  location = var.region
}
```

`terraform_data` (and the older `null_resource`) hold local-only logic — a value to
trigger replacement, or a `provisioner` for a local command — without managing a real
cloud resource.

---

## 2. Why it matters for platform engineering

- **Terraform is the lingua franca.** Most organizations' infrastructure is already
  in Terraform/OpenTofu; fluency is table stakes for a platform engineer.
- **The plan is a safety and review artifact.** "Show me the plan" is how teams
  review infrastructure change before it happens — the review gate that makes
  governance real (Module 05.7).
- **Providers unify a fragmented world.** One workflow and one language manage cloud,
  Kubernetes, DNS, SaaS, and more — you learn the loop once.
- **Variables + outputs are the seam** that will become reusable modules
  (Module 05.4): typed inputs, published outputs. Learn them cleanly now.

---

## 3. Mental model

**Terraform is a compiler for infrastructure.** Your `.tf` files are the source; the
dependency graph is the intermediate representation; the plan is the compiler's "here
is what I'll change"; apply is the link-and-run.

```text
  .tf files (HCL)        state + real world         plan (the diff)        apply
  ───────────────        ──────────────────         ───────────────        ─────
  desired state   ──▶   refresh actual state  ──▶   + create            ──▶ enact,
  (what you wrote)       (what exists now)           ~ update               update
                                                     - destroy              state
         ▲                                                                   │
         └───────────────────── you review the plan ◀──────────────────────┘
```

Rules to keep:

- **Never apply a plan you haven't read.** The plan is the contract.
- **References create order.** If B uses A's attribute, A comes first — no manual
  sequencing.
- **State is written by apply.** Guard it (Module 05.3).

---

## 4. Minimal implementation

The smallest honest Terraform project needs no cloud account at all — the
`random` and `local` providers create real managed resources (a random value, a file
on disk) through the exact same loop you'll use for GKE.

```hcl
terraform {
  required_providers {
    random = { source = "hashicorp/random", version = "~> 3.6" }
    local  = { source = "hashicorp/local",  version = "~> 2.5" }
  }
}

resource "random_pet" "name" {
  length = 2
}

resource "local_file" "greeting" {
  filename = "${path.module}/hello.txt"
  content  = "Hello from ${random_pet.name.id}\n"
}

output "service_name" {
  value = random_pet.name.id
}
```

```bash
terraform init          # downloads the random + local providers
terraform plan          # "+ 2 to add": a random_pet and a local_file
terraform apply -auto-approve
cat hello.txt           # "Hello from <some-random-pet>"
terraform state list    # random_pet.name, local_file.greeting
terraform apply         # idempotent: "No changes."
terraform destroy -auto-approve
```

Notice: `local_file.greeting` implicitly depends on `random_pet.name` because its
`content` references the pet's `id`. You wrote no ordering — the graph did it. This
is the whole tool in miniature; GKE just swaps the providers.

---

## 5. Hands-on lab

You'll build a real, multi-resource Terraform project **entirely locally and for
free** using the `random`, `local`, and `docker` providers — provisioning actual
Docker containers with Terraform — while practicing variables, outputs, `for_each`,
and the full `init/plan/apply/destroy` loop. The lesson's GKE code is included as a
read-only reference so you see the production shape.

➡️ **[Start the lab: Your first Terraform project](./lab/README.md)**

---

## 6. Production considerations

- **Pin versions.** Pin `required_version` and provider versions (`~>`). An
  unpinned provider can change behavior under you. Commit the `.terraform.lock.hcl`
  lock file.
- **`plan` before `apply`, always.** In CI, save the plan (`-out=tfplan`) and apply
  *that exact plan*, so what was reviewed is what runs.
- **Prefer `for_each` over `count`.** With `count`, removing the 2nd of three items
  renumbers the 3rd and Terraform destroys/recreates it. `for_each` keys are stable.
- **Mark secrets `sensitive`.** Outputs and variables that carry secrets should set
  `sensitive = true` so they don't print in logs (it's not encryption, just
  redaction).
- **Keep providers least-privileged.** The credentials Terraform runs with can
  create and destroy infrastructure — scope them tightly and run from CI, not
  laptops.
- **OpenTofu is a first-class choice.** If licensing or governance favors fully open
  source, `tofu` is compatible; teams adopt it with minimal change.

## 7. Common mistakes

- **Using `count` for things with identities.** `count` indexes by position, so
  insertions/removals churn unrelated resources. *Fix:* use `for_each` keyed by a
  stable name.
- **Hardcoding values that vary by environment.** Region, project, sizes baked into
  resources. *Why:* it seemed simpler. *Fix:* lift them into typed `variable`s with
  sensible defaults.
- **Adding `depends_on` everywhere "to be safe."** Over-declaring dependencies
  serializes the graph and hides real relationships. *Fix:* rely on implicit
  references; use `depends_on` only for genuinely hidden ordering.
- **Editing resources in the console, then applying.** Terraform reverts your manual
  change. *Fix:* change the code; if you must `ignore_changes` for a field another
  system owns, do so explicitly.
- **Committing `.terraform/` or state to Git.** The provider cache is large and
  state may hold secrets. *Fix:* `.gitignore` them; use a remote backend
  (Module 05.3).

## 8. Assessment

**Knowledge checks**

1. What's the difference between a resource and a data source?
2. How does Terraform decide the order to create resources? Give an example of an
   implicit dependency.
3. When should you reach for `for_each` instead of `count`?
4. What does `terraform plan` produce, and why should you never skip it?
5. What is `terraform_data` / `null_resource` for?

**Concept exercise**

> Explain how Terraform decides *what to change* **without using the words "plan,"
> "state," or "graph."** Describe the behavior to a developer who has only ever
> clicked in a cloud console.

**Debugging / trade-off exercise**

> A teammate wrote `resource "google_storage_bucket" "logs" { count = 3 … }` to make
> three buckets, named `logs-0/1/2`. They now need to delete `logs-1` permanently.
> What does Terraform do when they remove the middle one, why is that bad, and how
> would you have modeled it so deleting one bucket doesn't disturb the others?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** A resource is something Terraform *creates and manages* (and will change or
  destroy). A data source *reads* information about something Terraform does not
  manage; it's read-only input.
- **Q2:** It builds a dependency graph from references and applies in dependency
  order, parallelizing independent resources. Implicit example: a node pool that
  references `google_container_cluster.platform.name` is created after the cluster.
- **Q3:** When instances have stable identities (named things, per-environment
  resources) so adding/removing one shouldn't disturb the others. `for_each` keys by
  name; `count` keys by position.
- **Q4:** A diff of create/update/destroy actions it intends to take. Skipping it
  means applying changes you haven't reviewed — the opposite of a safe review gate.
- **Q5:** A resource with no cloud object, used to run local logic (a `provisioner`)
  or to force replacement via a `triggers_replace`/`triggers` value. Use sparingly.
- **Debugging:** With `count`, removing `logs-1` renumbers `logs-2` to index `1`;
  Terraform sees `logs-2` "gone" at index 2 and a changed resource at index 1, and
  plans to destroy/recreate — disturbing an unrelated bucket (and possibly deleting
  data). Model it with `for_each = toset(["app","audit","ops"])` so each bucket has a
  stable key and removing one leaves the rest untouched.

</details>

## 9. Further reading

- HashiCorp — [Terraform language documentation](https://developer.hashicorp.com/terraform/language)
- HashiCorp — [Resources, data sources, and meta-arguments](https://developer.hashicorp.com/terraform/language/resources)
- HashiCorp — [`for_each` vs `count`](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each)
- OpenTofu — [Language docs](https://opentofu.org/docs/language/)
- Terraform Registry — [`kreuzwerker/docker` provider](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs)
- Google — [`hashicorp/google` provider reference](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 05.1 — IaC Principles](../01-iac-principles/) · _Next:_ [Module 05.3 — Terraform State Management →](../03-terraform-state-management/)
