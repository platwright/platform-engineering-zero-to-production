# Lab — Build a shared action library

> You'll build the smallest real version of a platform's shared CI library: a
> **composite action** that computes an immutable tag, a **reusable workflow** that
> takes inputs and returns an output, and a **caller** that consumes both — every
> reference **pinned by commit SHA**. You'll validate everything locally with
> `actionlint` and reason about the supply-chain properties of your pins. Fully local
> and free.

**Estimated time:** ~50–70 minutes
**Type:** build
**Deliverable:** A validated three-part library:
[`actions/semver-tag/action.yml`](./actions/semver-tag/action.yml),
[`workflows/reusable-ci.yml`](./workflows/reusable-ci.yml), and
[`workflows/caller.yml`](./workflows/caller.yml).

## Objectives

- Author a composite action with inputs and outputs.
- Author a reusable workflow with `workflow_call` inputs, outputs, and secrets.
- Wire a caller that consumes both, pinned by SHA.
- Validate workflow YAML with `actionlint` and action metadata as YAML.

## Prerequisites

- The lesson [`../README.md`](../README.md).
- Everything from
  [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md).
- [`actionlint`](https://github.com/rhysd/actionlint) installed
  (`go install github.com/rhysd/actionlint/cmd/actionlint@latest`).
- `python3` **or** `node` for a quick YAML syntax check of the composite action
  (actionlint lints *workflows*, not action metadata files).
- No GitHub account or cloud is required to complete the core lab.

## Steps

1. **Read the composite action.**

   Open [`actions/semver-tag/action.yml`](./actions/semver-tag/action.yml). Note the
   three things that make it a composite action: `runs.using: "composite"`, every `run`
   step sets `shell: bash`, and it exposes an `outputs.tag` wired to a step output. It
   has **no** `runs-on` — it borrows the caller's job.

2. **Validate the action metadata as YAML.**

   ```bash
   python3 -c "import yaml,sys; yaml.safe_load(open('actions/semver-tag/action.yml')); print('action.yml OK')"
   ```

   (actionlint validates *workflows*; action metadata is checked as YAML and by GitHub
   when the action runs.)

3. **Read and validate the reusable workflow.**

   Open [`workflows/reusable-ci.yml`](./workflows/reusable-ci.yml). Trace the
   `on.workflow_call` block: typed `inputs`, an `outputs.tag` wired to a job output, and
   an optional `secrets.registry-token`. Validate it:

   ```bash
   actionlint workflows/reusable-ci.yml
   ```

4. **Read and validate the caller.**

   Open [`workflows/caller.yml`](./workflows/caller.yml). It does two things: calls the
   reusable workflow as a job (`uses: …/reusable-ci.yml@<SHA>`), and uses the composite
   action from a job step (`uses: …/semver-tag@<SHA>`). **Both are pinned by SHA**, with
   the version in a trailing comment. Validate:

   ```bash
   actionlint workflows/caller.yml
   ```

   Expect exit 0 for both workflow files.

5. **Prove the pin matters (thought + edit).**

   In a scratch copy, change a pinned `@<sha> # v1.4.0` to `@v1`. It still lints — that's
   the danger: nothing *local* tells you the upstream can now change under you. Write two
   sentences on what an attacker who controls that upstream could do with your job's
   token, and why the SHA pin removes that power. Revert your change.

6. **(Optional) Run it for real.**

   Copy `actions/semver-tag/` and the two workflows into a scratch GitHub repo under
   `.github/` (actions can live anywhere the `uses:` path points; reusable workflows must
   be under `.github/workflows/`). Point the caller's `uses:` at *your* repo and SHAs,
   push, and watch the composite action's `tag` output flow into the caller. Free on
   GitHub-hosted runners.

## Expected result

- `actionlint workflows/reusable-ci.yml` and `actionlint workflows/caller.yml` both exit
  0 with no findings.
- The composite action parses as valid YAML.
- You can explain, pointing at lines: inputs vs outputs vs secrets, `shell:` in a
  composite step, and why `@<SHA>` is safer than `@v1`.

## Cleanup

> The core lab creates only local files — nothing to tear down. If you did the optional
> Step 6, remove the scratch repo or its workflows.

```bash
# Optional: delete the scratch repo you created for Step 6, if any.
# gh repo delete <your-scratch-repo> --yes
```

## Reflection

- You changed the tag convention in one composite action. How many consumer repos did
  you have to touch, and what does that imply for platform leverage?
- When would you *not* pin a same-org, first-party action by SHA — and is the convenience
  worth it on a platform?
- The reusable workflow exposes `secrets: inherit` as an option. Why is passing secrets
  explicitly usually the better default?

## Stretch goals (optional)

- Add a `boolean` input (e.g. `push: false`) to `reusable-ci.yml` and branch on it with
  an `if:` so the same workflow serves PR validation and merge builds.
- Add a second composite action (`login-registry`) and compose it *inside* the reusable
  workflow's build job.
- Configure a `.github/dependabot.yml` snippet that would keep your `uses:` SHAs updated,
  and explain how it defeats pin-rot without reintroducing the mutable-tag risk.
