# Lab — Build an Idempotent Reconciler

> You'll build a tiny IaC engine from scratch: a script that keeps a **state file**,
> computes a **plan** (create / update / delete), applies only the difference, and
> **detects drift** when reality is changed behind its back. No cloud, no Terraform —
> just the mechanics every IaC tool implements.

**Estimated time:** ~40–60 minutes
**Type:** Build
**Deliverable:** A working `reconcile.sh` that is idempotent and drift-aware, plus a
short written answer to the reflection questions.

## Objectives

- Separate **desired state** (config) from **actual state** (a JSON state file) from
  **reality** (files on disk).
- Implement the **refresh → plan → apply** loop by hand.
- Observe idempotency: a second run with no changes is a no-op.
- Introduce **drift** and make your tool detect and report it.

## Prerequisites

- A shell with `bash`, `jq`, and `diff`. On Windows use **WSL2** (see
  [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)).
- The concepts from [the lesson](../README.md): idempotency, state, drift.
- A starter script is provided: [`reconcile.sh`](./reconcile.sh).

## Steps

1. **Inspect the starter.** Open [`reconcile.sh`](./reconcile.sh). It manages a set
   of "resources" (files with content) described in a `desired` block, persists what
   it manages to `state.json`, and acts only on differences. Make it executable:

   ```bash
   cd 05-infrastructure-as-code/01-iac-principles/lab
   chmod +x reconcile.sh
   ```

2. **First apply (create).** Run it once:

   ```bash
   ./reconcile.sh apply
   ```

   You should see three `+ create` lines and a new `state.json`. Look at the state:

   ```bash
   jq . state.json
   ```

   This JSON is your "map of managed things" — the same role Terraform's state file
   plays.

3. **Second apply (idempotency).** Run the exact same command again:

   ```bash
   ./reconcile.sh apply
   ```

   This time the plan is empty — **no changes**. Re-running is safe. That is
   idempotency, and it's why automated IaC can run on every merge without fear.

4. **Change desired state (update + delete).** Edit `reconcile.sh`: change the
   content of `app.conf`, and remove `cache.conf` from the `desired` list. Run a
   read-only plan first, then apply:

   ```bash
   ./reconcile.sh plan
   ./reconcile.sh apply
   ```

   The plan should show one `~ update` and one `- destroy`, and the apply should
   enact exactly those. Nothing else is touched.

5. **Introduce drift.** Now simulate a 2am console change — edit a managed file *by
   hand*, behind the tool's back:

   ```bash
   echo "hand-edited during an incident" >> managed/db.conf
   ./reconcile.sh plan
   ```

   Your reconciler compares reality to the state it recorded and reports **drift**
   on `db.conf`. Reconcile it:

   ```bash
   ./reconcile.sh apply
   ```

   The file is restored to the desired content. This is precisely what
   `terraform plan` does when someone clicks in the cloud console.

## Expected result

- `./reconcile.sh apply` is **idempotent**: the second identical run reports no
  changes.
- Changing the desired list produces a precise create/update/destroy plan.
- Hand-editing a managed file is detected as **drift** by `plan` and corrected by
  `apply`.
- You can explain, pointing at your own code, what *desired state*, *state file*,
  *plan*, and *drift* each are.

## Cleanup

> No cloud resources are created, so there's nothing to bill — but clean the
> working directory so reruns start fresh.

```bash
./reconcile.sh destroy   # removes managed files and clears state
rm -f state.json
rm -rf managed
```

## Reflection

- Your `state.json` is the only thing that lets the tool tell "not created yet" from
  "already created." What would happen if you deleted it and ran `apply` again?
  (Try it.) How does this map to Module 05.3's warnings about protecting state?
- You implemented drift detection by comparing *recorded state* to *reality*. A real
  tool also "refreshes" from reality before planning. Why is reading the real world
  before every plan important?
- Where did your reconciler assume an *order* between resources? Real infrastructure
  has dependencies (a subnet needs its VPC first). Keep this in mind for Module 05.2.

## Stretch goals (optional)

- Add a `--target=<name>` flag so a single resource can be reconciled in isolation —
  the same idea as `terraform apply -target`.
- Store a content hash in `state.json` and use it to detect drift without re-reading
  full file contents.
- Make `plan` exit non-zero when drift or changes are detected, so it could gate a
  CI job (foreshadowing Module 05.5).
