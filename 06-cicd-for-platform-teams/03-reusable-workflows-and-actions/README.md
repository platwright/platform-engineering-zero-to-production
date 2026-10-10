# Module 06.3 — Reusable Workflows and Composite Actions

> The fastest way to lose control of a platform's CI is to let every team copy-paste
> the same 80 lines of YAML into their repo. The moment you need to change the scan
> step, you're editing 200 files. This module teaches the two mechanisms that fix
> that — **composite actions** and **reusable workflows** — and the security practice
> that makes shared automation safe: **pinning everything by commit SHA**.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 06.2](../02-github-actions-deep-dive/), a GitHub account (free),
and [`actionlint`](https://github.com/rhysd/actionlint). The lab is local.

## Learning objectives

By the end of this module you will be able to:

- Distinguish a **composite action** (a reusable *sequence of steps*) from a
  **reusable workflow** (a reusable *set of jobs*) and choose correctly.
- Pass data in and out with **inputs**, **outputs**, and **secrets**.
- **Version** shared automation with releases and tags, and **pin by SHA** when you
  consume it.
- Organize a **central action library** that every repo draws from.
- Decide **when to build** a custom action versus adopt a community one.

---

## 1. Concept

### The copy-paste problem

Shared logic that lives as copied YAML has no single source of truth. Fixing a bug or
tightening the Trivy gate means a migration across every repository — and the repos
drift out of sync in the meantime. The platform move is the same one you've made all
course: **encode the paved road once, let teams consume it.** GitHub gives you two
tools for that, at two different granularities.

### Composite action — bundle *steps*

A **composite action** packages several steps behind one `uses:`. It runs *inside* a
caller's job, on the caller's runner. Reach for it when you want to say "do these five
steps as one" — checkout, set up a toolchain, log in, build.

```yaml
# action.yml  (a composite action)
name: "Build and tag"
description: "Compute an immutable tag and build the image."
inputs:
  image-name:
    description: "Image name."
    required: true
outputs:
  tag:
    description: "Computed tag."
    value: ${{ steps.meta.outputs.tag }}
runs:
  using: "composite"
  steps:
    - id: meta
      shell: bash     # composite run steps MUST set a shell
      run: echo "tag=${{ inputs.image-name }}:${GITHUB_SHA::7}" >> "$GITHUB_OUTPUT"
```

Key facts: it uses `inputs`/`outputs`, every `run` step needs an explicit `shell:`, and
it has no `runs-on` of its own — it borrows the caller's job.

### Reusable workflow — bundle *jobs*

A **reusable workflow** packages one or more whole **jobs**, called from another
workflow as a job via `uses:` plus `workflow_call`. Reach for it when you want to share
an *entire pipeline* — its own runners, matrix, environments, and gates.

```yaml
# .github/workflows/app-ci.yml  (a reusable workflow)
on:
  workflow_call:
    inputs:
      image-name: { required: true, type: string }
    outputs:
      tag: { value: ${{ jobs.build.outputs.tag }} }
    secrets:
      registry-token: { required: false }
jobs:
  build:
    runs-on: ubuntu-latest
    outputs: { tag: ${{ steps.m.outputs.tag }} }
    steps:
      - uses: actions/checkout@v4
      - id: m
        run: echo "tag=${{ inputs.image-name }}:${GITHUB_SHA::7}" >> "$GITHUB_OUTPUT"
```

### Which one? A decision rule

```text
Sharing a few STEPS inside someone's job      → composite action
Sharing one or more whole JOBS / a pipeline   → reusable workflow
Need your own runners/matrix/environments     → reusable workflow
Need to drop into an existing job mid-stream   → composite action
```

The two compose: a reusable workflow's jobs can *use* your composite actions. That's
the normal shape of a mature library.

### Inputs, outputs, secrets

- **Inputs** are typed (`string`, `boolean`, `number`) for reusable workflows; composite
  action inputs are strings. Always give sensible defaults.
- **Outputs** let callers read a result — a computed tag, a digest, a plan summary.
- **Secrets** are passed explicitly to reusable workflows (`secrets:` block) or in bulk
  with `secrets: inherit`. Prefer explicit passing so a workflow only sees what it needs.

### Versioning and the central registry

Put shared automation in **one or two dedicated repositories** — a `platform-actions`
repo for composite actions and a `platform-workflows` repo for reusable workflows — so
there is a single source of truth and a single place to review changes. Cut **releases**
(Git tags like `v1.4.0`) so consumers have stable versions to point at, and maintain a
moving major tag (`v1`) for convenience.

```text
platform-actions/                      platform-workflows/
├── semver-tag/action.yml              └── .github/workflows/
├── build-and-push/action.yml                ├── app-ci.yml        (reusable)
└── terraform-plan/action.yml                └── terraform.yml     (reusable)
   releases: v1.0.0, v1.1.0, v1 →            releases: v2.0.0, v2.3.1, v2 → …
```

### Pin by SHA — the security rule that matters

A tag like `@v1` is **mutable**: whoever controls the upstream repo can move it to
point at new code. If that upstream is compromised, your pipeline silently starts
running the attacker's steps — with your repo's token. This is not hypothetical;
real supply-chain attacks have worked exactly by moving a popular action's tag.

The defense is to pin third-party (and even your own) actions by **immutable commit
SHA**, with the human version in a trailing comment:

```yaml
- uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0
```

A moved tag can't change a SHA. Let Dependabot propose SHA bumps so pinning doesn't
mean going stale. First-party, same-org actions are lower risk, but pinning is still
the platform-grade default.

### Build vs adopt

Don't rebuild `actions/checkout`. **Adopt** well-maintained, popular community actions
for commodity tasks (checkout, cloud auth, Docker buildx) — pinned by SHA. **Build** a
custom action when you need to bake in *your organization's* policy: the exact scan
thresholds, the required labels, the signing step every image must pass. Custom actions
are where your platform's opinions live.

---

## 2. Why it matters for platform engineering

Reuse is the mechanism behind "the platform owns the pipeline." When the scan gate, the
signing step, and the tag convention live in one composite action and one reusable
workflow, the platform team can improve security for every team with a single
versioned release — no mass migration, no drift. That is enormous leverage: one change,
hundreds of repos.

SHA pinning is where platform engineering's "security is structural" principle meets
CI. Your pipelines carry the most powerful tokens you own; an unpinned action is a
standing invitation for a supply-chain compromise to use them. Pinning turns a trust
decision you make *once* (review this exact commit) into something an attacker can't
quietly revoke by moving a tag. This library and these pins are the substrate for the
Project 1 build pipeline and the Project 2 Terraform pipeline you assemble next.

## 3. Mental model

```text
     COMPOSITE ACTION vs REUSABLE WORKFLOW
     ─────────────────────────────────────

  Caller workflow
  ├── job: build  (runs-on: ubuntu-latest)
  │     ├── step ── uses: org/platform-actions/semver-tag@<SHA>   ◄── COMPOSITE
  │     │            (expands into several steps, in THIS job)        = bundle of STEPS
  │     └── step ── run: docker build ...
  │
  └── job: ci ──── uses: org/platform-workflows/.github/workflows/app-ci.yml@<SHA>
                    (runs as its OWN job(s), own runner/matrix)     ◄── REUSABLE WORKFLOW
                    with: {…}  secrets: inherit                        = bundle of JOBS

  Supply chain:   @v1   (mutable tag — can be MOVED by upstream)   ✗
                  @<40-char SHA>  (immutable — cannot change)      ✓  + Dependabot bumps

  One line: steps → composite action; jobs/pipelines → reusable workflow; pin both by SHA.
```

## 4. Minimal implementation

Feel the difference by factoring one duplicated idea — "compute an immutable tag" — into
a composite action, then calling it:

```yaml
# platform-actions/semver-tag/action.yml
name: "Semantic version tag"
description: "Compute main-<shortsha> style tag."
inputs:
  prefix: { description: "Optional prefix", required: false, default: "" }
outputs:
  tag: { description: "Computed tag", value: ${{ steps.c.outputs.tag }} }
runs:
  using: "composite"
  steps:
    - id: c
      shell: bash
      run: |
        t="${GITHUB_REF_NAME//\//-}-${GITHUB_SHA::7}"
        [ -n "${{ inputs.prefix }}" ] && t="${{ inputs.prefix }}:${t}"
        echo "tag=${t}" >> "$GITHUB_OUTPUT"
```

```yaml
# a caller, pinning the action by SHA
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0
      - id: v
        uses: platform-org/platform-actions/semver-tag@a1b2c3d4e5f6…  # v1.4.0
        with: { prefix: payments }
      - run: echo "tag is ${{ steps.v.outputs.tag }}"
```

One definition, every repo consumes it, and the pin makes the supply chain auditable.
In the lab you'll build this plus a reusable workflow and wire a caller to both.

## 5. Hands-on lab

You'll build a tiny but real shared library: a **composite action** that computes an
immutable tag, a **reusable workflow** that accepts inputs and returns an output, and a
**caller** that consumes both — pinned by SHA. You'll validate every file with
`actionlint` and reason about the supply-chain properties of your pins.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **A real central registry.** Put actions and reusable workflows in dedicated repos
  with CODEOWNERS, required reviews, and their own CI that tests the actions themselves.
- **Pin by SHA, automate the bumps.** SHA pins everywhere; Dependabot (or Renovate) to
  propose updates so pinning doesn't rot into staleness.
- **Version deliberately.** Semantic versioning for your library; a moving major tag for
  convenience, but publish release notes and a changelog — consumers depend on you.
- **Test your actions.** A broken shared action breaks everyone at once. Give the
  library a test matrix and a canary consumer before you move the major tag.
- **Least-secret passing.** Prefer explicit `secrets:` over `secrets: inherit` so a
  called workflow sees only what it needs.
- **Document inputs/outputs.** Treat the action/workflow interface like a public API —
  because to your developers, it is.

## 7. Common mistakes

- **Copy-pasting YAML across repos** — no source of truth; a fix means editing N files.
  *Fix:* a composite action or reusable workflow in a central library.
- **Pinning third-party actions by moving tag (`@v1`, `@master`)** — a compromised
  upstream silently runs in your pipeline with your tokens. *Fix:* pin by SHA with a
  version comment; automate bumps.
- **Reaching for a reusable workflow to share three steps** — heavyweight; you wanted a
  composite action. *Fix:* match granularity — steps→composite, jobs→reusable workflow.
- **Forgetting `shell:` in a composite action** — the run step fails to parse. *Fix:*
  every composite `run` sets `shell: bash` (or similar).
- **`secrets: inherit` everywhere** — passes every secret to code that may not need it.
  *Fix:* pass only the secrets required, explicitly.
- **Rebuilding commodity actions** — maintaining your own checkout/buildx wrapper for no
  reason. *Fix:* adopt popular community actions (pinned); build only org-specific policy.

## 8. Assessment

**Knowledge checks**

1. In one sentence each, what is a composite action and what is a reusable workflow?
2. You want to share an entire build-scan-sign pipeline, with its own runner — which do
   you use?
3. Why must you pin third-party actions by SHA rather than by tag?
4. How do you return a value from a reusable workflow to its caller?
5. What's one thing you should *build* a custom action for, and one you shouldn't?

**Concept exercise**

> Explain the difference between sharing "a few steps" and "a whole pipeline" **without
> naming composite actions or reusable workflows.** Describe where each shared unit runs
> and what it brings with it.

**Trade-off / debugging exercise**

> Your org pins every action by `@v1`. A popular third-party action's maintainer account
> is compromised and `v1` is moved to malicious code; within an hour, build tokens across
> the org are exfiltrated. Walk through exactly how the attack reached your pipelines, and
> the change that would have prevented it — plus how you'd keep that change from going stale.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** A composite action bundles several *steps* behind one `uses:`, running inside
  the caller's job. A reusable workflow bundles whole *jobs* called via `workflow_call`.
- **Q2:** A reusable workflow — it brings its own `runs-on`, matrix, and environments.
- **Q3:** Tags are mutable; upstream (or an attacker who compromises it) can move `@v1`
  to new code that then runs in your pipeline with your permissions. A SHA is immutable.
- **Q4:** Declare it under `on.workflow_call.outputs` with a `value:` referencing a job
  output; the caller reads `needs.<job>.outputs.<name>` (or the job's `outputs`).
- **Q5:** Build: org-specific policy (your scan thresholds, signing, required labels).
  Don't build: commodity tasks like checkout or cloud auth — adopt and pin those.
- **Debugging:** The mutable `@v1` tag let the attacker point your `uses:` at new code
  without changing your YAML; your runner executed it with the job's `GITHUB_TOKEN`/cloud
  identity and exfiltrated it. SHA pinning (`@<40-char sha>`) would have made the moved
  tag irrelevant. Keep it fresh with Dependabot/Renovate proposing reviewed SHA bumps.

</details>

## 9. Further reading

- GitHub — [Creating a composite action](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
- GitHub — [Reusing workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- GitHub — [Security hardening: using third-party actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions)
- GitHub — [Keeping your actions up to date with Dependabot](https://docs.github.com/en/code-security/dependabot/working-with-dependabot/keeping-your-actions-up-to-date-with-dependabot)
- OpenSSF — [Scorecard: Pinned-Dependencies check](https://github.com/ossf/scorecard/blob/main/docs/checks.md#pinned-dependencies)
- StepSecurity — [Why pin GitHub Actions by commit SHA](https://www.stepsecurity.io/blog/pinning-github-actions-for-enhanced-security-a-complete-guide)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 06.2 — GitHub Actions Deep Dive](../02-github-actions-deep-dive/) · _Next:_ [Module 06.4 — Pipeline Templates as a Platform Product](../04-pipeline-templates-as-product/)
