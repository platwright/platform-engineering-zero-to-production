# Module 05.1 — IaC Principles

> Before any Terraform, you need to understand the *ideas* every IaC tool
> implements: describing infrastructure as **declarative code in version control**,
> making changes **idempotent**, tracking **state**, and detecting **drift**. This
> module builds those concepts from first principles — you'll even write a tiny
> idempotent "reconciler" by hand — so that Terraform later feels obvious rather
> than magical.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** [Phase 1](../../01-platform-foundations/) for context, and a shell with `bash` and `jq`. No cloud, no Terraform yet.

## Learning objectives

By the end of this module you will be able to:

- Define Infrastructure as Code and explain why version control is the foundation.
- Distinguish **declarative** from **imperative** approaches and say why platforms
  prefer declarative.
- Explain **idempotency** and why it is the property that makes re-running safe.
- Explain what **state** is, why IaC tools keep it, and what **drift** is.
- Describe the IaC lifecycle and judge when IaC is *not* the right tool.

---

## 1. Concept

### What Infrastructure as Code actually means

**Infrastructure as Code (IaC)** is the practice of describing your infrastructure —
servers, clusters, networks, load balancers, buckets, databases, DNS records, IAM
policies — in **machine-readable files kept under version control**, and using a
tool to create and change that infrastructure from those files instead of by hand.

The "in version control" half is not a detail; it is the point. The moment your
infrastructure lives in Git you gain the things the clicking approach can never
give you:

- **Review** — a change is a pull request, not an untracked console action.
- **History** — `git log` tells you who changed what, when, and why.
- **Reproducibility** — the same files produce the same environment, every time.
- **Rollback** — revert the commit, re-apply, and you are back.
- **Collaboration** — many engineers change infrastructure without stepping on
  each other.

### Declarative vs imperative

There are two ways to tell a computer to get infrastructure into a certain shape.

**Imperative** means you specify the *steps*: "create a VPC, then create a subnet,
then create a cluster, then attach a node pool." A shell script full of `gcloud` or
`aws` commands is imperative. It works — once. Run it again and it fails because the
VPC already exists, or it creates a duplicate.

**Declarative** means you specify the *desired end state*: "I want a VPC, a subnet,
a cluster, and a node pool, configured like this." The tool figures out what to
create, change, or delete to make reality match. Run it again and — if nothing
changed — it does nothing.

```text
IMPERATIVE  "Do these steps."            → you own the HOW and the ordering
DECLARATIVE "This is what should exist." → the tool owns the HOW; you own the WHAT
```

Platform engineering overwhelmingly prefers **declarative** IaC because the desired
state is reviewable, diffable, and safe to apply repeatedly. You describe the
destination, not the turn-by-turn directions.

### Idempotency: the property that makes it safe

An operation is **idempotent** if applying it many times has the same effect as
applying it once. "Set the thermostat to 20°C" is idempotent — do it ten times, the
room is still 20°C. "Raise the thermostat by one degree" is **not** idempotent — do
it ten times and you are sweating.

Idempotency is what lets you run the same IaC repeatedly without fear. The tool
inspects what exists, compares it to the desired state, and only acts on the
difference. This is why a second `apply` with no changes is a safe no-op — the
cornerstone of trustworthy automation.

### State: how the tool knows what it manages

To compute the difference between *desired* and *actual*, a tool needs to know which
real-world resources it is responsible for. It keeps a record called **state**:
essentially a mapping from the resources in your code to the real resource
identifiers in the cloud.

```text
desired state (your code)     state file (the map)        real world (the cloud)
   resource "bucket" "logs" ─▶ logs = projects/x/bucket/42 ─▶ an actual GCS bucket
```

Without state, the tool cannot tell the difference between "this bucket does not
exist yet, create it" and "I already created this bucket, leave it alone." State is
the memory that makes reconciliation possible — and, as you'll see in Module 05.3,
managing it well is a whole discipline.

### Drift: when reality wanders off

**Drift** is any divergence between what your code says *should* exist and what
*actually* exists. Someone opens the cloud console at 2am during an incident and
bumps a node count; a different tool edits a firewall rule; a resource is deleted by
hand. Now production no longer matches its definition.

Drift is dangerous because it is invisible until it bites: your next `apply` tries
to "fix" the manual change (reverting an emergency hotfix), or your code no longer
describes what is really running. Detecting and reconciling drift is a core platform
responsibility (Module 05.7).

---

## 2. Why it matters for platform engineering

IaC is the substrate the rest of your platform stands on:

- **Reproducibility is the product.** A platform promises teams a consistent,
  paved-road environment. You cannot deliver "consistent" from hand-built
  infrastructure that drifted apart months ago.
- **Review and governance become possible.** "No manual console changes; every
  change is a reviewed PR" is only enforceable when infrastructure *is* code.
- **Disaster recovery stops being a prayer.** If an environment is fully described
  in code, recreating it after a loss is an `apply`, not a two-week archaeology
  project.
- **Leverage.** Reusable IaC modules let a small platform team stamp out correct,
  secure infrastructure for dozens of product teams on demand — the economic case
  for the whole discipline.
- **It is the foundation for GitOps and self-service.** Later phases (GitOps,
  Crossplane) all assume desired state lives in Git. IaC principles are what make
  that work.

Without IaC, every later capability — golden paths, self-service environments,
drift-free production — is impossible.

---

## 3. Mental model

Hold this model: **IaC is a control loop around desired state.**

```text
            ┌──────────────────────────────────────────────────┐
            │                                                  │
   ┌────────▼─────────┐   compare    ┌──────────────────┐      │
   │  DESIRED STATE   │─────────────▶│   DIFF (plan):    │      │
   │  (code in Git)   │              │  create/change/   │      │
   └────────▲─────────┘              │  destroy          │      │
            │                        └─────────┬────────┘      │
            │                                  │ apply          │
   ┌────────┴─────────┐              ┌─────────▼────────┐       │
   │   STATE (map of  │◀─────────────│   REAL WORLD     │───────┘
   │  managed things) │   refresh    │  (the cloud)     │  drift pushes
   └──────────────────┘              └──────────────────┘  real ≠ desired
```

Three rules worth remembering a year from now:

1. **You edit desired state, never the real world directly.** The console is
   read-only in your mind.
2. **The tool reconciles; you review the plan.** Never apply a diff you don't
   understand.
3. **State is precious.** Lose it or corrupt it and the tool forgets what it owns.

---

## 4. Minimal implementation

Let's prove the core ideas without Terraform. We'll manage one "resource" — a
directory that should contain exactly a set of files — with a hand-written,
**idempotent, declarative, stateful** reconciler.

The *desired state* is a list. The *state* is what currently exists. The script
computes a *diff* and applies only the difference.

```bash
#!/usr/bin/env bash
set -euo pipefail

# --- desired state (this is our "code") ---
desired=("app.conf" "db.conf" "cache.conf")
target_dir="./managed"

mkdir -p "$target_dir"

# --- refresh: read the real world into "current state" ---
mapfile -t current < <(cd "$target_dir" && ls -1 2>/dev/null || true)

# --- plan + apply: create what's missing ---
for f in "${desired[@]}"; do
  if [[ ! -f "$target_dir/$f" ]]; then
    echo "+ create $f"
    touch "$target_dir/$f"
  fi
done

# --- plan + apply: destroy what's no longer desired ---
for f in "${current[@]}"; do
  if [[ ! " ${desired[*]} " == *" $f "* ]]; then
    echo "- destroy $f"
    rm -f "$target_dir/$f"
  fi
done

echo "converged. desired = ${desired[*]}"
```

Run it once and it creates three files. Run it again — **it prints nothing to
create or destroy**. That is idempotency. Delete `db.conf` by hand (that's *drift*)
and run again: it re-creates exactly the missing file. Add `cache.conf` to the
desired list and remove `app.conf`: the next run creates one and destroys the other.

You just built, from first principles, the exact loop Terraform runs: **refresh →
diff (plan) → apply**, acting only on the difference. Terraform adds a real state
file, a dependency graph, and thousands of providers — but the idea is this script.

---

## 5. Hands-on lab

You'll extend this idea into a small reconciler that keeps a **real state file**
(JSON) separate from reality, then deliberately introduce drift and watch your tool
detect and report it — the same mechanics Terraform uses, with none of the cloud
cost.

➡️ **[Start the lab: Build an idempotent reconciler](./lab/README.md)**

---

## 6. Production considerations

- **State is a single point of truth — protect it.** In real IaC, losing state
  means the tool no longer knows what it owns. Production state is stored remotely,
  locked, versioned, and backed up (Module 05.3).
- **Drift detection must be continuous.** Manual changes *will* happen during
  incidents. A scheduled job that runs a read-only `plan` and alerts on drift is
  standard platform hygiene (Module 05.7).
- **IaC and configuration management are complementary, not rivals.** IaC
  (Terraform, OpenTofu, Crossplane) provisions *infrastructure* — the cluster, the
  network, the bucket. Configuration management (Ansible, Chef, Puppet) configures
  *inside* already-running machines — packages, files, services. Many platforms use
  IaC to create the fleet and config management (or, increasingly, immutable images
  and Kubernetes) to configure it. Know which problem you're solving.
- **Immutability beats mutation.** Prefer replacing resources (new image, new
  instance) over mutating them in place. It eliminates a class of drift and
  configuration rot.
- **Everything through the pipeline.** In production, humans don't run `apply` from
  laptops; CI does, with review gates. This is both a safety and an audit control.

## 7. Common mistakes

- **Treating IaC as a one-time bootstrap.** Writing code to stand up an environment,
  then editing it by hand forever after. *Why:* the console is faster in the moment.
  *Fix:* make code the *only* way infrastructure changes; forbid manual edits and
  detect drift.
- **Imperative scripts masquerading as IaC.** A pile of `gcloud create …` commands
  in a repo is version-controlled, but it isn't idempotent or declarative — re-runs
  break or duplicate. *Fix:* describe desired state; let a declarative tool
  reconcile.
- **Ignoring state.** Deleting, hand-editing, or not backing up the state file.
  *Why:* it looks like "just a file." *Fix:* treat state as production data —
  remote, locked, versioned (Module 05.3).
- **Pretending drift won't happen.** Assuming nobody will ever touch the console.
  *Why:* incidents create pressure to click. *Fix:* expect drift; detect it on a
  schedule and reconcile deliberately.
- **Using IaC for genuinely one-off exploration.** Writing a module to spin up a
  throwaway spike you'll delete in an hour. *Fix:* for true one-offs and
  prototypes, a quick manual action or script is fine — IaC's payoff is
  *repetition* and *longevity*.

## 8. Assessment

**Knowledge checks**

1. Why is "in version control" essential to the definition of IaC, not an optional
   extra?
2. Give one everyday example each of an idempotent and a non-idempotent action.
3. What is the state file for, and what breaks if it's lost?
4. What is drift, and why is it dangerous even when the manual change "worked"?
5. Name a situation where IaC is *not* the right choice.

**Concept exercise**

> Explain idempotency and declarative desired state **without using the words
> "Terraform," "apply," or "state."** Use an analogy a non-engineer would get.

**Debugging / trade-off exercise**

> During an incident, an on-call engineer manually scales a node pool from 3 to 10
> nodes in the cloud console to absorb load, and it resolves the incident. The IaC
> code still says `3`. Walk through what happens on the *next* `apply`, why that's a
> problem, and two different ways a mature platform team should handle this — one
> process change and one technical control.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Version control is what gives IaC its value — review, history,
  reproducibility, rollback, collaboration. A declarative file that only ever lives
  on one laptop is just a fancier manual process; the "code" part means *managed
  like code*.
- **Q2:** Idempotent: "set the volume to 5," "ensure this file exists." Non-idempotent:
  "turn the volume up by one," "append a line to this file."
- **Q3:** State maps your coded resources to real cloud resource IDs so the tool can
  diff desired vs actual. Lose it and the tool no longer knows what it owns — it may
  try to recreate everything (duplicates/conflicts) or refuse to manage existing
  resources.
- **Q4:** Drift is divergence between code and reality. Even a "working" manual
  change is dangerous because the next `apply` will try to revert it back to what
  the code says, and because your code no longer describes what's actually running —
  so reviews and recovery are based on a lie.
- **Q5:** A genuine one-off: a throwaway spike, a quick debugging VM you'll destroy
  in an hour, a true prototype. IaC's cost (writing, reviewing, maintaining)
  only pays off with repetition or longevity.
- **Debugging:** On the next `apply`, the tool sees desired=3, actual=10, and plans
  to *scale back to 3* — undoing the emergency fix, possibly re-triggering the
  incident. Process fix: codify the change (update the module to the new baseline,
  via PR) before the next apply, and treat emergency console changes as incidents
  that *must* be reconciled. Technical control: automated drift detection (a
  scheduled read-only plan that alerts), plus pipeline-only applies so a stray local
  `apply` can't silently revert prod.

</details>

## 9. Further reading

- HashiCorp — [What is Infrastructure as Code?](https://developer.hashicorp.com/terraform/intro)
- OpenTofu — [Introduction & docs](https://opentofu.org/docs/)
- Martin Fowler — [Infrastructure as Code](https://martinfowler.com/bliki/InfrastructureAsCode.html)
- ThoughtWorks — [Kief Morris, *Infrastructure as Code* (book site)](https://infrastructure-as-code.com/)
- Google Cloud — [Immutable infrastructure](https://cloud.google.com/architecture/best-practices-for-operating-containers#immutability)
- Red Hat — [IaC vs configuration management (Ansible)](https://www.redhat.com/en/topics/automation/what-is-infrastructure-as-code-iac)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Phase 4 overview](../README.md) · _Next:_ [Module 05.2 — Terraform Fundamentals →](../02-terraform-fundamentals/)
