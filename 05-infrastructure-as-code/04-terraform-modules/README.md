# Module 05.4 — Terraform Modules

> Copy-pasting HCL between environments is how IaC rots. **Modules** are Terraform's
> unit of reuse: a parameterized, versioned package with a clean interface. This
> module teaches how to structure modules, design their interfaces, compose them, and
> version an internal module library — the building blocks a platform team ships as
> its paved road.

**Estimated effort:** ~2 hours (theory + lab)
**You'll need:** [Module 05.2](../02-terraform-fundamentals/) and [05.3](../03-terraform-state-management/), Terraform/OpenTofu installed. The lab is local and free.

## Learning objectives

By the end of this module you will be able to:

- Explain **root modules** vs **child modules** and the standard file layout.
- Design a module **interface**: minimal required inputs, sensible defaults,
  meaningful outputs.
- **Compose** larger infrastructure from smaller modules.
- Consume **published** modules from the Terraform Registry and build an **internal**
  library versioned with Git tags.
- Judge **when to abstract** into a module and when not to.

---

## 1. Concept

### Every configuration is already a module

In Terraform, a **module** is just a directory of `.tf` files. The directory you run
`terraform apply` in is the **root module**. When one module calls another, the
callee is a **child module**. So you've been writing modules since Module 05.2 —
"making a module" is mostly about giving a child module a clean interface and reusing
it.

```text
root module (you run apply here)
└── module "network" { source = "./modules/vpc" … }   ← a child module call
    module "cluster" { source = "./modules/gke" … }   ← another child module call
```

### Standard module structure

A well-formed module has three conventional files (plus optional extras):

```text
modules/gke-cluster/
├── main.tf        # the resources this module manages
├── variables.tf   # the INPUTS (the interface the caller fills in)
├── outputs.tf     # the OUTPUTS (what the caller can read back)
├── versions.tf    # required_version + required_providers
└── README.md      # how to use it (the module is a product; document it)
```

- **`variables.tf` is the module's API.** Each `variable` is a knob the caller sets.
- **`outputs.tf` is the return value.** Other modules wire to these.
- **`main.tf` is the implementation** — hidden behind the interface.

### Interface design: the heart of a good module

A module is a product with developers as customers (sound familiar from Phase 1?).
Good interfaces share qualities:

- **Minimal required inputs.** Require only what truly varies; everything else gets a
  sensible default. A caller should stand up a correct resource with two or three
  inputs, not twenty.
- **Safe, opinionated defaults.** Encode good practice *once* — private nodes,
  encryption on, least-privilege — so every consumer gets it for free.
- **Validated inputs.** Use `validation` blocks and types to reject bad input early
  with a clear message.
- **Useful outputs.** Export the things callers actually need (endpoints, names, IDs)
  and nothing secret unless marked `sensitive`.
- **Stable.** Changing an input's name or meaning is a breaking change for every
  consumer — version it (below).

```hcl
variable "node_count" {
  type        = number
  default     = 3
  description = "Number of nodes in the primary pool."

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 100
    error_message = "node_count must be between 1 and 100."
  }
}
```

### Composition: small modules, assembled

Rather than one mega-module, platform teams build **small, focused modules** (a VPC,
a GKE cluster, a node pool, a bucket, a secret) and **compose** them in environment
root modules. Outputs of one feed inputs of the next:

```hcl
module "vpc" {
  source = "../../modules/vpc"
  name   = "platform-${var.environment}"
}

module "gke" {
  source     = "../../modules/gke-cluster"
  name       = "platform-${var.environment}"
  network    = module.vpc.network_name     # output → input: implicit dependency
  subnetwork = module.vpc.subnet_name
}
```

### Published vs internal modules

- **Published modules** live on the [Terraform Registry](https://registry.terraform.io/)
  (and OpenTofu's registry) — community/vendor modules you consume by `source` and
  `version`. Great for common building blocks; review them like any dependency.
- **Internal module library** — your own modules, shared across repos. Version them
  with **Git tags** and pin consumers to a tag:

```hcl
module "gke" {
  source = "git::https://github.com/acme/tf-modules.git//gke-cluster?ref=v1.4.0"
  # ...
}
```

Pinning a `ref` is what makes upgrades **deliberate**: a consumer moves from `v1.4.0`
to `v1.5.0` on purpose, in a reviewed PR — not silently.

### When *not* to make a module

Abstraction has a cost. Don't wrap a single resource in a module just to feel
organized, and don't build a configurable mega-module with forty toggles. A good
rule: **extract a module when you have the same shape of infrastructure in two or
more places, and the interface is small.** Premature or over-parameterized modules
are harder to use than the raw resources.

---

## 2. Why it matters for platform engineering

- **Modules are the paved road, as code.** The platform team's opinions — secure
  defaults, naming, tagging, network layout — live in modules that every team
  consumes. Build the right thing once; everyone gets it.
- **They turn copy-paste drift into versioned upgrades.** Instead of each team's
  forked YAML rotting apart, a single module evolves and teams adopt new versions
  deliberately.
- **They encode compliance by construction.** "All buckets are encrypted and
  private" becomes true-by-default when the only sanctioned way to make a bucket is
  your module.
- **They're how a small team scales.** A five-person platform team can equip
  hundreds of developers because the hard decisions are packaged, not re-made each
  time.

## 3. Mental model

**A module is a function; the root module is `main()`.**

```text
  module = function(inputs) -> outputs

  module "gke" {               f(                          returns
    source     = "./gke"          name       = "...",         module.gke.endpoint
    name       = "platform"       node_count = 3,             module.gke.name
    node_count = 3            )  -> { endpoint, name, ... }
  }

  root module = main(): calls functions, wires outputs → inputs, owns the state
```

Rules to keep:

- **Inputs in, outputs out, implementation hidden.** Callers shouldn't need to read
  `main.tf`.
- **Version your functions.** A changed signature breaks callers; tag releases.
- **Compose, don't inflate.** Many small functions beat one giant configurable one.

## 4. Minimal implementation

Here's the smallest useful module and a root module that calls it — using the free
`random`/`local` providers so you can run it immediately. The module wraps "a named
config file with a generated token" behind a two-input interface.

```hcl
# modules/service-config/variables.tf
variable "name" {
  type = string
}

variable "log_level" {
  type    = string
  default = "info"
}

# modules/service-config/main.tf
resource "random_password" "token" {
  length  = 16
  special = false
}
resource "local_file" "config" {
  filename = "${path.root}/${var.name}.conf"
  content  = "name=${var.name}\nlog_level=${var.log_level}\ntoken=${random_password.token.result}\n"
}

# modules/service-config/outputs.tf
output "path" { value = local_file.config.filename }
```

```hcl
# main.tf (root module) — compose two instances of the module
module "payments" {
  source    = "./modules/service-config"
  name      = "payments"
  log_level = "debug"
}
module "orders" {
  source = "./modules/service-config"
  name   = "orders"       # log_level defaults to "info"
}

output "config_paths" {
  value = [module.payments.path, module.orders.path]
}
```

```bash
terraform init && terraform apply -auto-approve
# → creates payments.conf (debug) and orders.conf (info), each with a token.
```

Two calls, one definition, zero copy-paste. Swap the implementation for a GKE cluster
and you have the lab.

## 5. Hands-on lab

You'll build a small **internal module library** and compose it from two
environments (`dev` and `prod`) that differ only by inputs — exactly the structure
from the outline's GKE example, but implemented locally and free. You'll see one
module definition drive two environments, and practice interface design, defaults,
and validation. A ready-to-extend module skeleton is provided.

➡️ **[Start the lab: Build an internal module library](./lab/README.md)**

## 6. Production considerations

- **Version everything; pin consumers.** Tag module releases (`v1.2.3`,
  semver-style) and pin each consumer to a tag. Treat module upgrades like dependency
  upgrades — reviewed and tested.
- **Document the interface.** A module without a README is a riddle. Describe each
  input, its default, and show an example call. (`terraform-docs` can generate this.)
- **Keep modules provider-agnostic where sensible, but don't over-abstract.** A
  module that tries to support three clouds usually serves none well.
- **Validate inputs aggressively.** `validation` blocks and precise types turn
  runtime cloud errors into fast, clear plan-time failures.
- **Beware breaking changes.** Renaming an input or output breaks every consumer.
  Deprecate gracefully; bump the major version; communicate.
- **Test modules in isolation.** Contract-test the interface, not the implementation
  (Module 05.5).

## 7. Common mistakes

- **The mega-module.** One module with dozens of flags trying to cover every case.
  *Why:* fear of duplication. *Fix:* compose several small, focused modules instead.
- **Abstracting too early.** Wrapping a single resource used in one place. *Why:*
  tidiness. *Fix:* wait until you have two-plus real consumers and a small interface.
- **Unpinned module sources.** `source = ".../modules.git//gke"` with no `?ref=`.
  *Why:* convenience. *Fix:* pin a tag so upgrades are deliberate and reproducible.
- **Leaking implementation through the interface.** Requiring callers to pass
  low-level IDs the module could derive. *Fix:* require the minimum; compute the
  rest internally.
- **No defaults, so every call is huge.** Forcing callers to specify everything.
  *Fix:* sensible, secure defaults; require only what truly varies.

## 8. Assessment

**Knowledge checks**

1. What are the three conventional files in a module, and what role does each play?
2. What makes an input "part of the module's interface"? Why is renaming one a
   breaking change?
3. How do you pin an internal module to a specific version, and why does that matter?
4. Give a concrete signal that some HCL *should* be extracted into a module — and one
   that it shouldn't.
5. How does one module's output become another module's input?

**Concept exercise**

> Explain what a Terraform module gives you **without using the words "module,"
> "Terraform," or "reuse."** (Describe it to someone who knows functions in a
> programming language.)

**Architecture / trade-off exercise**

> Your team has three environments whose GKE clusters are identical except for node
> count and region. One engineer proposes a single `gke` module with a `node_count`
> and `region` input, called three times. Another proposes three copies of the raw
> resources "so each environment can diverge freely." Argue for the module approach,
> then name the one situation where the copy approach is actually defensible.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** `variables.tf` (inputs / interface), `main.tf` (the resources /
  implementation), `outputs.tf` (return values other modules consume). Plus
  `versions.tf` and a README in practice.
- **Q2:** Any `variable` (its name, type, meaning) is the public API callers depend
  on. Renaming/retyping it breaks every caller's block — hence it's a breaking change
  that warrants a major version bump.
- **Q3:** Pin the `source` with `?ref=vX.Y.Z` (Git tag) or `version` (registry). It
  makes upgrades deliberate and builds reproducible — consumers move versions in a
  reviewed PR, not silently.
- **Q4:** Extract when the same shape appears in two-plus places with a small, stable
  interface. Don't extract a single-use single resource, or when every consumer would
  need a different large set of flags (over-parameterization).
- **Q5:** By reference: `module.vpc.network_name` used as an input to the `gke`
  module creates an implicit dependency and passes the value.
- **Trade-off:** The module removes duplication, encodes secure defaults once, makes
  upgrades uniform, and keeps environments genuinely identical (a feature). The copy
  approach is defensible only when environments must diverge in *structural,
  unpredictable* ways (e.g., a legacy prod with a fundamentally different topology you
  don't want to model as options) — but that's rare and usually a smell.

</details>

## 9. Further reading

- HashiCorp — [Modules](https://developer.hashicorp.com/terraform/language/modules)
  and [Module development & structure](https://developer.hashicorp.com/terraform/language/modules/develop)
- HashiCorp — [Standard module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)
- Terraform Registry — [Browse and publish modules](https://registry.terraform.io/browse/modules)
- [`terraform-docs` — generate module documentation](https://terraform-docs.io/)
- HashiCorp — [Input variable validation](https://developer.hashicorp.com/terraform/language/values/variables#custom-validation-rules)
- OpenTofu — [Modules](https://opentofu.org/docs/language/modules/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 05.3 — Terraform State Management](../03-terraform-state-management/) · _Next:_ [Module 05.5 — Terraform Testing and Quality →](../05-terraform-testing-and-quality/)
