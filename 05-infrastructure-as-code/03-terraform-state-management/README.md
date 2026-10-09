# Module 05.3 — Terraform State Management

> State is the most under-appreciated and most dangerous part of Terraform. It's the
> map between your code and the real world — and if two people apply at once, or the
> file is lost, or someone hand-edits it, you get corruption, duplicated resources,
> or destroyed production. This module teaches **why state exists**, how to store it
> safely (remote backends with locking), how to inspect and surgically manipulate
> it, and how to isolate it to limit blast radius.

**Estimated effort:** ~2 hours (theory + lab)
**You'll need:** [Module 05.2](../02-terraform-fundamentals/) and Terraform/OpenTofu installed. The lab runs locally and free.

## Learning objectives

By the end of this module you will be able to:

- Explain what Terraform state is and why local state fails for teams.
- Configure a **remote backend** and reason about **state locking**.
- Inspect state with `state list` / `state show`, and safely manipulate it with
  `state mv` / `state rm` / `import`.
- Migrate state between backends without data loss.
- Use **workspaces** and **state isolation** to manage environments and **blast
  radius**.

---

## 1. Concept

### What state actually holds

When you ran `apply` in Module 05.2, Terraform wrote `terraform.tfstate` — a JSON
document mapping each resource in your code to the **real resource's identifier** and
its last-known attributes:

```text
code:          resource "docker_container" "svc" (web)
state entry:   docker_container.svc["web"]  →  id = 3f9c…, name = "web-cosmic-ray", …
real world:    an actual running container with id 3f9c…
```

State exists because Terraform must answer one question on every run: *"for each
thing in the code, does a real resource already exist, and is it as I left it?"*
Without state it would have no memory — it couldn't tell "create this" from "I
already made this." (You implemented exactly this `state.json` idea by hand in
Module 05.1.)

### Why local state breaks for teams

A single `terraform.tfstate` on your laptop is fine for a solo experiment and a
disaster for a team:

- **It's not shared.** Your teammate's apply has no idea what yours created, so it
  tries to create everything again → duplicates and conflicts.
- **No locking.** If two applies run at once, they interleave writes and **corrupt**
  the state file.
- **No durability.** Laptop dies, file lost — Terraform forgets everything it owns.
- **Secrets in the clear.** State can contain sensitive attributes (passwords, keys)
  in plaintext; a file in a repo or on a laptop is an exposure.

### Remote backends

A **backend** determines where state is stored and how operations run. A **remote
backend** keeps the single source of truth in shared, durable storage:

- **Google Cloud Storage (GCS)**, **AWS S3**, **Azure Blob**, or **Terraform/HCP
  Cloud**.
- Enables **sharing** (everyone reads/writes the same state), **durability**
  (versioned object storage), **encryption at rest**, and **locking**.

```hcl
terraform {
  backend "gcs" {
    bucket = "acme-tf-state"
    prefix = "platform/prod"
  }
}
```

### State locking

A **lock** prevents two applies from mutating state simultaneously. Backends acquire
a lock before writing and release it after. GCS and S3 support locking (S3 via a
DynamoDB table or, newer, native lockfiles); HCP Cloud does it natively. If someone
else is mid-apply, your run waits or errors with a lock message — exactly what you
want, because concurrent writes corrupt state.

### Inspecting state

Read-only commands that never change anything:

```bash
terraform state list                     # every managed resource address
terraform state show docker_container.svc # attributes of one resource
terraform show                            # the whole state, human-readable
terraform output                          # output values
```

### Manipulating state (carefully)

Sometimes the *code* is right but the *state* needs surgery — you renamed a resource,
split a module, or imported something created by hand. These commands change the map,
not the infrastructure:

- **`terraform state mv A B`** — rename/move a resource's *address* in state (e.g.
  after renaming it in code) so Terraform doesn't destroy-and-recreate it.
- **`terraform state rm A`** — stop managing a resource *without destroying it*
  (Terraform forgets it; the real thing stays).
- **`terraform import A <id>`** — adopt an existing real resource into state so
  Terraform manages it going forward.

> These are power tools. Always back up state first and run with care — a wrong
> `state rm` on production can orphan resources; a wrong edit can destroy them.

### Workspaces and state isolation

A **workspace** gives you *multiple state files for the same configuration* —
`terraform workspace new staging` keeps `staging` state separate from `default`.
They're handy for small dev/stage/prod splits of identical config.

But workspaces share the *same backend and code*, so they're a **weak** isolation
boundary. For real environments, platform teams prefer **separate state per
environment** (and often per team/component) via **directory or backend
separation** — because that controls **blast radius**: a bad apply in `dev` can't
touch `prod` state it cannot even reach. (More in Module 05.7.)

```text
Weak isolation (workspaces)        Strong isolation (separate states)
─────────────────────────          ─────────────────────────────────
one config + backend               environments/dev/   → its own backend/state
  ├─ workspace: dev                 environments/stg/  → its own backend/state
  ├─ workspace: staging             environments/prod/ → its own backend/state
  └─ workspace: prod               a mistake in dev literally cannot reach prod
```

---

## 2. Why it matters for platform engineering

- **State is production data.** Treat it with the care you'd give a database:
  remote, locked, versioned, encrypted, backed up. Losing it is an outage-grade
  event.
- **Locking is how teams apply safely.** Dozens of engineers and CI jobs touch the
  same infrastructure; locking is what prevents them from corrupting each other.
- **Blast radius is a design decision you make in state layout.** How you split
  state determines what a single mistake can destroy. This is one of the highest-
  leverage decisions a platform team makes.
- **State surgery is a real on-call skill.** Renames, module refactors, and imports
  all require confident, careful state manipulation. Fumbling it causes incidents.

---

## 3. Mental model

**State is a shared ledger; the backend is the vault; the lock is the pen only one
person can hold.**

```text
        ┌─────────────────────── remote backend (the vault) ───────────────────────┐
        │  versioned, encrypted object storage                                      │
        │                                                                           │
        │        ┌──────────────┐     lock      ┌──────────────┐                    │
   you ─┼──────▶ │  state file  │ ◀───(pen)───▶ │   teammate   │ ─┐                 │
        │        │  (ledger)    │               │   / CI job   │  │ only one writes │
        │        └──────────────┘               └──────────────┘  │ at a time       │
        └───────────────────────────────────────────────────────────────────────── ┘
```

Three rules:

1. **One source of truth, stored remotely.** Never the laptop for anything shared.
2. **Lock before you write.** Concurrency without locks corrupts.
3. **Change the map with intent.** `state mv/rm/import` move the ledger entries;
   back up first, every time.

---

## 4. Minimal implementation

You don't need a cloud bucket to understand remote state — the **`local` backend**
and a **state move** demonstrate the mechanics. Start with the local-backend default
and inspect it:

```bash
# A tiny config using the random provider (no cloud):
cat > main.tf <<'EOF'
terraform {
  required_providers { random = { source = "hashicorp/random", version = "~> 3.6" } }
}
resource "random_pet" "old" { length = 2 }
EOF

terraform init
terraform apply -auto-approve
terraform state list          # random_pet.old
```

Now rename the resource in code from `old` to `new`. Naïvely, Terraform would
**destroy** `old` and **create** `new`. Instead, move it in state so the *same* real
resource keeps its identity:

```bash
sed -i 's/"old"/"new"/' main.tf
terraform state mv random_pet.old random_pet.new   # move the ledger entry
terraform plan                                     # "No changes." — nothing destroyed
```

That is the heart of state management: the real resource never changed, but you
updated the **map** so code and state agree. Swapping the `local` backend for `gcs`
or `s3` changes *where the ledger lives and how it locks* — not these mechanics.

---

## 5. Hands-on lab

You'll run a project on the local backend, **migrate its state to a different
backend** (still local, to stay free), observe **locking** by holding a lock during a
simulated concurrent apply, and perform **state surgery** with `state mv` and
`state rm` — then prove nothing in the real world was destroyed. The lesson shows the
GCS backend block for production; the lab stays local and free.

➡️ **[Start the lab: State migration and surgery](./lab/README.md)**

---

## 6. Production considerations

- **Always remote, always locked, always versioned.** Use GCS/S3/HCP with object
  versioning and encryption on. Versioning is your undo button after a bad apply.
- **Restrict who can read state.** State may contain secrets; lock down bucket IAM
  as tightly as the infrastructure it describes.
- **Back up before surgery.** `terraform state pull > backup.tfstate` before any
  `mv`/`rm`/`import`. If it goes wrong, `state push` the backup.
- **Isolate state to bound blast radius.** Separate state per environment and per
  high-risk component (networking, IAM) so one mistake can't cascade.
- **Don't overuse workspaces for prod.** They're convenient but share code and
  backend; prefer directory/backend separation for environments that matter.
- **Never hand-edit state JSON.** Use the `state` subcommands. Manual edits silently
  corrupt the structure Terraform depends on.

## 7. Common mistakes

- **Committing `terraform.tfstate` to Git.** It's shared-mutable and may hold
  secrets; Git is neither locked nor encrypted. *Fix:* remote backend +
  `.gitignore` state.
- **No locking.** "We both applied and now resources are duplicated/half-created."
  *Why:* concurrent writes. *Fix:* a backend with locking enabled; let it block the
  second run.
- **`state rm` expecting it to delete the resource.** It only stops managing it —
  the real resource is orphaned and still costs money. *Fix:* use `destroy` to
  delete; use `rm` only to intentionally hand off ownership.
- **Renaming a resource without `state mv`.** Terraform destroys the old and creates
  a new one — downtime and data loss for stateful resources. *Fix:* `state mv` (or a
  `moved {}` block) to preserve identity.
- **One giant state for everything.** A single mistake can destroy the whole estate,
  and plans get slow. *Fix:* split by environment/component.

## 8. Assessment

**Knowledge checks**

1. Why does local state fail as soon as a second engineer joins?
2. What does state locking prevent, and what happens to a second apply when a lock
   is held?
3. What's the difference between `terraform state rm` and `terraform destroy`?
4. When do you need `terraform state mv`, and what goes wrong if you skip it?
5. Why do platform teams prefer separate state per environment over workspaces for
   production?

**Concept exercise**

> Explain why Terraform needs state at all **without using the words "state,"
> "backend," or "file."** (Describe the problem it solves.)

**Debugging / trade-off exercise**

> On-call at 2am: a `terraform apply` failed halfway and now every subsequent run
> errors with *"Error acquiring the state lock."* The engineer who started it is
> asleep. Walk through how you'd diagnose whether the lock is stale, what
> `force-unlock` does and its danger, and what you'd verify about state *before and
> after* breaking the lock.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Local state isn't shared — the second engineer's Terraform has no record of
  what the first created, so it tries to create everything again (duplicates), and
  there's no lock to stop concurrent corruption.
- **Q2:** Locking prevents two operations from writing state at the same time, which
  would corrupt it. A second apply either waits for the lock or fails fast with a
  lock error identifying who holds it.
- **Q3:** `state rm` tells Terraform to *forget* a resource (stop managing it); the
  real resource keeps running (and billing). `destroy` *deletes* the real resource.
- **Q4:** When you rename/move a resource's address in code (or restructure modules).
  Without `state mv`, Terraform sees the old address gone and a new one added, and
  destroys+recreates — fatal for stateful resources. (A `moved {}` block is the
  declarative equivalent.)
- **Q5:** Workspaces share one backend and one codebase, so isolation is weak and a
  mistake can reach the wrong environment. Separate state (separate backends/dirs)
  means a bad `dev` apply literally cannot address `prod` — real blast-radius
  control.
- **Debugging:** Diagnose with `terraform force-unlock`'s reported lock info (who,
  when, operation) and the backend's lock record; check the object's last-modified
  time and whether the holder's process is truly dead. `force-unlock <ID>` removes
  the lock *without* checking that the other operation finished — dangerous because
  if that apply is secretly still running you'll corrupt state. Before breaking it:
  `terraform state pull > backup` and confirm no live apply. After: `plan` to verify
  state is coherent (no unexpected creates/destroys) before doing anything else.

</details>

## 9. Further reading

- HashiCorp — [State](https://developer.hashicorp.com/terraform/language/state) and
  [Backend configuration](https://developer.hashicorp.com/terraform/language/backend)
- HashiCorp — [`terraform state` commands](https://developer.hashicorp.com/terraform/cli/commands/state)
- HashiCorp — [Manage resources in state (tutorial)](https://developer.hashicorp.com/terraform/tutorials/state/state-cli)
- HashiCorp — [`moved` block for refactoring](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring)
- OpenTofu — [State and backends](https://opentofu.org/docs/language/state/)
- Google — [Store Terraform state in a GCS bucket](https://cloud.google.com/docs/terraform/resource-management/store-state)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 05.2 — Terraform Fundamentals](../02-terraform-fundamentals/) · _Next:_ [Module 05.4 — Terraform Modules →](../04-terraform-modules/)
