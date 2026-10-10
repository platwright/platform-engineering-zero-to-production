# Module 06.2 — GitHub Actions Deep Dive

> GitHub Actions is the engine for every pipeline in this phase. This module takes it
> apart from first principles — triggers, jobs, steps, contexts, environments, and
> concurrency — and then spends its energy on the single most important platform
> security move in CI: **keyless authentication with OIDC**, so your pipelines reach
> the cloud with short-lived, scoped credentials instead of a long-lived secret
> waiting to leak.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 06.1](../01-cicd-fundamentals-for-platform/), a GitHub account
(free), and optionally [`actionlint`](https://github.com/rhysd/actionlint). The core lab
is local; a cloud account is optional and clearly marked.

## Learning objectives

By the end of this module you will be able to:

- Describe the **anatomy** of a workflow: events → jobs → steps → runners.
- Choose the right **trigger** (`push`, `pull_request`, `workflow_dispatch`, `schedule`)
  for a given pipeline.
- Read and use **contexts** (`github`, `env`, `vars`, `secrets`, `runner`, `job`, `steps`).
- Gate deployments with **GitHub Environments** and **protection rules**.
- Explain why **keyless OIDC** beats long-lived cloud secrets, and wire it up.
- Use **concurrency groups** to stop two runs from colliding on one environment.

---

## 1. Concept

### Workflow anatomy

A workflow is a YAML file in `.github/workflows/`. Four nouns do all the work:

- **Event** — *what* starts the run (`on:`). A push, a pull request, a button, a timer.
- **Job** — a unit that runs on one **runner** (a fresh VM/container). Jobs run in
  parallel by default; `needs:` makes one wait for another.
- **Step** — an ordered action inside a job: either a `run:` shell command or a
  `uses:` reusable action.
- **Runner** — the machine the job executes on (`runs-on: ubuntu-latest` for
  GitHub-hosted, or a self-hosted label).

```yaml
on: [push]                 # event
jobs:
  build:                   # job
    runs-on: ubuntu-latest # runner
    steps:
      - uses: actions/checkout@v4   # step (an action)
      - run: echo "hello"           # step (a command)
```

Each job gets a **clean machine**. Nothing persists between jobs unless you pass it
explicitly (outputs, artifacts, or a cache). That isolation is a feature: it makes
runs reproducible and stops one job's mess from leaking into another.

### Events: pick the trigger that matches the intent

- **`pull_request`** — run validation on proposed changes *before* merge. This is
  where your `plan`, lint, and scan gates live.
- **`push`** (often filtered to `main`) — run the pipeline that acts on the merged
  result: publish an artifact, apply infrastructure, deploy.
- **`workflow_dispatch`** — a manual button (with typed inputs). Use for promotions,
  one-off applies, and break-glass.
- **`schedule`** — a cron timer. Use for drift detection and nightly re-scans.

```yaml
on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:
  schedule:
    - cron: "0 3 * * *"
```

### Contexts: where your data comes from

**Contexts** are read-only objects you interpolate with `${{ }}`:

- **`github`** — the event payload: `github.ref`, `github.sha`, `github.event_name`,
  `github.actor`, `github.repository`.
- **`env`** — environment variables you set at workflow/job/step scope.
- **`vars`** — organization/repo **configuration variables** (non-secret).
- **`secrets`** — encrypted secrets. *Masked* in logs, but still long-lived if they are
  static credentials — which is exactly what OIDC lets you avoid.
- **`runner`** — facts about the machine (`runner.os`, `runner.temp`).
- **`job` / `steps`** — status and **outputs** of the current job and prior steps
  (`steps.build.outputs.digest`).

### GitHub Environments and protection rules

A GitHub **Environment** (for example `dev`, `staging`, `production`) is a named
deployment target you attach rules to:

- **Required reviewers** — a human must approve before a job targeting that
  environment runs. This is your four-eyes gate for `apply`.
- **Wait timer** — a forced delay (soak time) before deploy.
- **Deployment branches** — only `main` may deploy to `production`.
- **Environment secrets/variables** — scoped per environment, so prod credentials
  never load on a dev run.

```yaml
jobs:
  deploy-prod:
    runs-on: ubuntu-latest
    environment: production   # pauses here until a required reviewer approves
    steps:
      - run: ./deploy.sh
```

### Keyless OIDC: the headline act

The old way to let a pipeline touch your cloud: mint a static access key, paste it
into a GitHub secret, and hope it never leaks, never gets logged, and someone
remembers to rotate it. That secret is **long-lived, broadly scoped, and invisible
once stolen** — the worst properties a credential can have.

**OIDC (OpenID Connect)** removes the stored secret entirely. On each run, GitHub
mints a short-lived, signed **JSON Web Token (JWT)** describing *who is asking*: the
repository, the branch/tag (`ref`), the environment, the workflow. Your cloud
provider is configured to **trust GitHub's token issuer** and to exchange that JWT
for **short-lived cloud credentials** — but only when the token's claims match
conditions you set (e.g. "repo = `platform-org/infra` AND environment =
`production`"). Nothing durable is stored in GitHub.

```text
No stored secret. A fresh, scoped identity is minted per run and expires in minutes.
```

To request the token, the workflow must be granted the `id-token: write` permission:

```yaml
permissions:
  id-token: write   # allows the runner to request an OIDC token
  contents: read
```

### Concurrency: don't let two runs collide

Two pipelines applying to `production` at once is a recipe for corrupted state and
half-applied changes. A **concurrency group** serializes runs that share a key, and
can cancel superseded ones:

```yaml
concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: false   # for apply/deploy: queue, don't cancel mid-apply
```

Use `cancel-in-progress: true` for PR validation (newer commit supersedes the old
run) and `false` for anything that mutates state (let the in-flight apply finish).

### Self-hosted runners: when and why

GitHub-hosted runners are ephemeral and maintenance-free — prefer them. Reach for
**self-hosted** runners only when you genuinely need: access to a private network,
a specific GPU/architecture, or caches too large for hosted runners. The cost is that
*you* now own their security and patching — and a self-hosted runner on a public repo
is a well-known attack vector. Default to hosted; justify self-hosted.

---

## 2. Why it matters for platform engineering

Platform pipelines hold the keys to the kingdom: they can change infrastructure,
publish the base image everyone pulls, and deploy to production. That makes their
*credentials* the single juiciest target in your whole system. Moving from stored
secrets to **keyless OIDC** removes the highest-value, longest-lived secret from your
pipelines — there is nothing durable left to steal, and access is scoped to exactly
the repo, branch, and environment that should have it.

Environments and concurrency turn the fuzzy idea "production is special" into
*mechanical* controls: a required reviewer the pipeline literally waits for, and a
lock that stops two applies racing. These are the primitives you'll compose into the
Project 1 and Project 2 pipelines — the signing step, the Trivy gate, the Terraform
`apply` behind a prod environment — later in this phase.

## 3. Mental model

```text
      GITHUB ACTIONS — anatomy + the OIDC token exchange
      ──────────────────────────────────────────────────

  EVENT ──► WORKFLOW ──► JOB (fresh runner) ──► STEP ──► STEP ──► ...
  push        .yml         runs-on:              uses:    run:
  pull_req                 ubuntu-latest         action   command
  dispatch                   │
  schedule                   │ needs: (ordering)   contexts: ${{ github.* env.* steps.* }}
                             ▼
                       ENVIRONMENT  ── required reviewer? ──► (wait) ──► run

  Keyless cloud access (no stored secret):

     Runner ──(1) request OIDC token (id-token: write)──► GitHub OIDC issuer
     Runner ◄─(2) short-lived signed JWT (claims: repo, ref, environment) ─┘
     Runner ──(3) present JWT ──► Cloud STS ──(4) verify issuer + claims──► short-lived creds
     Runner ──(5) use creds for a few minutes, then they expire

  One line: a workflow is events→jobs→steps, gated by environments, authenticating
  with a fresh scoped identity per run instead of a stored key.
```

## 4. Minimal implementation

Start with the smallest workflow that shows anatomy *and* contexts — no cloud yet:

```yaml
name: hello
on:
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: hello-${{ github.ref }}
  cancel-in-progress: true

jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Show context
        run: |
          echo "event=${{ github.event_name }}"
          echo "ref=${{ github.ref }}  sha=${{ github.sha }}"
          echo "actor=${{ github.actor }}  os=${{ runner.os }}"
      - id: build
        run: echo "digest=sha256:deadbeef" >> "$GITHUB_OUTPUT"
      - name: Use a prior step's output
        run: echo "built ${{ steps.build.outputs.digest }}"
```

Two things to notice: the job runs on a clean machine, and data flows forward through
**outputs** (`$GITHUB_OUTPUT`) and **contexts**, never through shared disk. Now
contrast the two ways to reach the cloud:

```yaml
# ❌ The old way: a long-lived secret, stored forever, scoped to everything.
#    - run: gcloud auth activate-service-account --key-file=<(echo "${{ secrets.GCP_SA_KEY }}")

# ✅ Keyless: request a short-lived token; exchange it for minutes-long creds.
permissions:
  id-token: write
  contents: read
```

You'll wire the full keyless exchange in the lab.

## 5. Hands-on lab

You'll build a real workflow from scratch — triggers, contexts, concurrency — and
validate it with `actionlint`. Then you'll author a **keyless OIDC** job that
authenticates to Google Cloud with *no stored secret*, understand each claim, and
(optionally, if you have a free-tier cloud account) see the token exchange succeed.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **Keyless everywhere.** Make OIDC the default for every cloud and registry that
  supports it; treat a remaining long-lived credential as tech debt with a removal date.
- **Scope the trust conditions tightly.** On the cloud side, bind the role to a
  specific repo *and* ref/environment. A trust policy that accepts "any repo in the
  org" is a lateral-movement risk.
- **Least-privilege `permissions:`.** Set `permissions:` to the minimum at the top of
  every workflow (`contents: read`), and widen per-job only where needed.
- **Protect production with Environments.** Required reviewers, deployment branches,
  and environment-scoped secrets are the difference between "prod is special" as a
  slogan and as an enforced rule.
- **Concurrency on anything that mutates.** `cancel-in-progress: false` for apply/deploy;
  `true` for PR validation.
- **Prefer hosted runners.** Reach for self-hosted only with a concrete reason, and then
  isolate them (ephemeral, no secrets on disk, never on untrusted PRs).
- **Pin actions.** Use pinned versions (ideally by SHA — Module 06.3), not a moving
  `@master`, so a compromised upstream can't silently change your pipeline.

## 7. Common mistakes

- **Storing a static cloud key as a secret** — long-lived, broadly scoped, invisible
  when leaked. *Fix:* keyless OIDC with `id-token: write` and a scoped trust policy.
- **Over-broad `permissions:`** — leaving the default read/write token on every job.
  *Fix:* default `contents: read`; grant more only where required.
- **No concurrency control on deploy** — two merges apply to prod simultaneously and
  corrupt state. *Fix:* a `concurrency` group keyed to the environment, no cancel.
- **`pull_request_target` misuse** — running untrusted PR code with write permissions.
  *Fix:* use `pull_request` for validation; never expose secrets to fork PRs.
- **Trust condition too loose** — the cloud role accepts tokens from any repo/branch.
  *Fix:* bind to the exact repository and ref/environment claim.
- **Secrets in `echo`** — printing a secret, which may survive in logs. *Fix:* never log
  secrets; rely on masking and, better, don't have a stored secret at all.

## 8. Assessment

**Knowledge checks**

1. What are the four building blocks of a workflow, and what runs in parallel by default?
2. Which trigger fits each: pre-merge validation, nightly drift check, a manual
   promotion, acting on a merge to `main`?
3. What claims does a GitHub OIDC token carry, and how does the cloud use them?
4. What single permission must a workflow have to request an OIDC token?
5. When do you want `cancel-in-progress: true` versus `false`?

**Concept exercise**

> Explain how a pipeline can authenticate to a cloud provider **without storing any
> credential**, and why that is safer — *without using the words "OIDC" or "token."*
> Describe what is presented, what is checked, and how long the access lasts.

**Trade-off / debugging exercise**

> A workflow deploys to production. It uses `on: push` with no branch filter, no
> `environment:`, a static `secrets.CLOUD_KEY`, and no `concurrency`. List four
> concrete risks this design creates and the specific change that fixes each.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Events, jobs, steps, runners. Jobs run in parallel unless ordered with
  `needs:`.
- **Q2:** `pull_request` (pre-merge validation), `schedule` (nightly drift),
  `workflow_dispatch` (manual promotion), `push` filtered to `main` (act on merge).
- **Q3:** Claims like repository, `ref`, environment, and workflow. The cloud verifies
  the token's issuer signature and matches the claims against a trust policy, then
  issues short-lived credentials.
- **Q4:** `id-token: write`.
- **Q5:** `true` for PR validation (a newer commit should supersede the running job);
  `false` for apply/deploy (let the in-flight mutation finish rather than cancel it).
- **Debugging:** (1) No branch filter → any branch can deploy to prod — add
  `branches: [main]` and/or deployment-branch rules. (2) No `environment:` → no required
  reviewer — add `environment: production`. (3) Static key → leak risk — switch to keyless
  OIDC. (4) No `concurrency` → racing applies — add a concurrency group keyed to prod with
  `cancel-in-progress: false`.

</details>

## 9. Further reading

- GitHub — [Workflow syntax for GitHub Actions](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- GitHub — [About security hardening with OpenID Connect](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- GitHub — [Using environments for deployment](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- GitHub — [Contexts reference](https://docs.github.com/en/actions/learn-github-actions/contexts)
- Google Cloud — [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- AWS — [Configuring OpenID Connect in GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 06.1 — CI/CD Fundamentals for Platform Teams](../01-cicd-fundamentals-for-platform/) · _Next:_ [Module 06.3 — Reusable Workflows and Composite Actions](../03-reusable-workflows-and-actions/)
