# Module 06.6 — IaC Pipelines

> Infrastructure is the highest-stakes thing a platform changes: an `apply` can resize a
> cluster, rewrite a firewall rule, or delete a database. This module builds the pipeline
> that makes those changes **safe and reviewable** — plan on every pull request, apply on
> merge behind environment gates, detect drift on a schedule, and authenticate with a
> **least-privilege, keyless** identity. This is the `plan → review → apply` engine behind
> Project 2's promotion-by-PR.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 06.2](../02-github-actions-deep-dive/),
[Phase 4 · Infrastructure as Code](../../05-infrastructure-as-code/), and
[Terraform](https://developer.hashicorp.com/terraform/install). The core lab is local/free.

## Learning objectives

By the end of this module you will be able to:

- Build a **plan-on-PR** workflow that comments the plan for review.
- **Apply on merge** automatically for dev and behind a **manual gate** for production.
- Detect **drift** with a scheduled plan that alerts when reality diverges from code.
- Handle **state locking / conflicts** safely in CI.
- Scope **least-privilege, keyless (OIDC)** credentials: read-only to plan, write to apply.
- Explain where **Atlantis** fits as a PR-based alternative.

---

## 1. Concept

### The plan is the review artifact

Terraform's superpower is that `plan` shows *exactly* what will change before anything
happens. An IaC pipeline turns that into a review ritual: on every pull request, run
`plan` and **post the output as a PR comment**, so a human reviews the concrete diff —
"this will replace the database" — not just the HCL. The plan, attached to the PR, is the
thing reviewers approve.

```text
PR opened ─► fmt ─► validate ─► tfsec/checkov ─► PLAN ─► comment the plan on the PR
            (cheap, decisive first; the plan is what humans actually review)
```

### Apply on merge, gated per environment

Once reviewers approve and the PR merges, the pipeline **applies**. But not all
environments are equal, so you gate them differently using **GitHub Environments**
(Module 06.2):

- **dev** — apply **automatically** on merge. Fast feedback; low blast radius.
- **staging / production** — apply behind a **required reviewer** (and optionally a wait
  timer and `main`-only deployment branches). The job *pauses* until a human approves.

```text
merge to main ─► apply(dev)  ──auto──►  apply(staging) ──gate──►  apply(production) ──gate──►
                 low risk               required reviewer          required reviewer, main-only
```

This is the mechanical version of "platform changes need stronger review than app
changes" from Module 06.1 — the gate is enforced by the platform, not by politeness.

### Drift detection: reality vs code

Code says one thing; someone clicked something in the console; now they disagree. That's
**drift**, and it's silent until an incident. Detect it with a **scheduled** workflow: run
`terraform plan` nightly against production. A truly reconciled environment produces an
**empty** plan. `terraform plan -detailed-exitcode` returns `0` for no changes and `2` for
a non-empty plan — so a non-empty plan can **fail the job loudly** and alert you.

```text
nightly: terraform plan -detailed-exitcode
          exit 0 → in sync (quiet)
          exit 2 → DRIFT → red build + alert (fail loud, Module 06.1)
```

### State conflicts and locking

Terraform **state** is the source of truth it diffs against, and two applies touching it
at once will corrupt it. Two mechanisms keep CI safe:

- **State locking.** A remote backend (S3+DynamoDB, GCS, Terraform Cloud) takes a **lock**
  during `plan`/`apply`; a second run waits or fails rather than racing.
- **Concurrency groups.** A GitHub `concurrency` group keyed to the environment, with
  `cancel-in-progress: false`, ensures only one state-mutating run proceeds at a time and
  an in-flight apply is never cancelled mid-write.

Together they turn "two merges at once" from a corruption risk into an orderly queue.

### Least-privilege, keyless credentials

An IaC pipeline holds the power to change infrastructure — so its credentials are the
highest-value target you own. Two rules:

- **Keyless (OIDC).** No stored cloud keys; the pipeline authenticates with a short-lived,
  scoped identity per run (Module 06.2). Nothing durable to steal.
- **Least privilege per job.** The **plan** job needs only **read** access (it previews);
  only the **apply** job needs **write**. Bind separate cloud roles so a PR plan — which
  can run code from a fork — can never mutate anything.

```text
plan job  → OIDC → read-only role   (safe to run on PRs)
apply job → OIDC → write role       (only after merge + environment gate)
```

### Atlantis: the PR-native alternative

**Atlantis** is a self-hosted app that runs the whole flow *inside the PR*: it comments
the `plan` automatically, and you type `atlantis apply` in a PR comment to apply, with
approval rules enforced. It centralizes Terraform automation, locking, and policy for
many repos — appealing for larger orgs that want a single, consistent Terraform workflow
rather than a workflow file copied into every repo. The trade-off is operating another
service; GitHub Actions needs nothing extra to run. Same concepts either way: plan on PR,
gated apply, locking.

---

## 2. Why it matters for platform engineering

Infrastructure changes are where a platform team can do the most damage and the most good.
This pipeline makes the damage *hard* and the good *routine*: every change is previewed and
reviewed as a concrete plan, applied behind gates that match blast radius, and watched for
drift so the platform's "infrastructure is code" claim stays true instead of quietly
rotting. Least-privilege keyless credentials mean the most dangerous automation you run
also has the smallest standing attack surface.

It's also the final piece of the course's throughline. Project 2 promotes changes by
**pull request into a config repository**: you open a PR, the pipeline plans and shows the
diff, reviewers approve, merge applies behind a gate — and in Phase 6 a GitOps controller
reconciles the result. The `plan → review → apply` loop you build here is exactly that
promotion mechanism, and the same review-by-diff discipline carries straight into GitOps.

## 3. Mental model

```text
     IaC PIPELINE — plan to review, gated apply, watched for drift
     ────────────────────────────────────────────────────────────

  PULL REQUEST ─► fmt ─► validate ─► tfsec ─► PLAN ─► 💬 comment plan on PR
     (read-only OIDC role — safe even for fork PRs)        │ humans review the DIFF
                                                           ▼
  MERGE to main ─► apply(dev) ──auto──► apply(staging) ──[gate]──► apply(prod) ──[gate]──►
     (write OIDC role)   low blast radius     required reviewer       required reviewer, main-only
                            │ state lock + concurrency(group=env, cancel-in-progress:false)
                            ▼
  NIGHTLY ─► plan -detailed-exitcode ─► exit 2? ─► DRIFT → red + alert (fail loud)

  One line: the plan is the review; gates match blast radius; state is locked; drift is
            caught on a schedule; and credentials are keyless and least-privilege.
```

## 4. Minimal implementation

Feel the review loop locally, with no cloud — the `local` provider makes `plan`/`apply`
real and free:

```bash
terraform init          # downloads the provider (no cloud account needed)
terraform fmt -check     # cheap, decisive — fails fast on formatting
terraform validate
terraform plan -out tfplan   # the artifact a reviewer would read
```

The two ideas the pipeline automates are visible already — the **plan as review artifact**
and **drift as a non-empty plan**:

```bash
terraform apply tfplan            # apply the EXACT plan you reviewed (no surprises)

# Later, detect drift: a reconciled workspace plans empty; a changed one exits 2.
terraform plan -detailed-exitcode
echo "exit $?   # 0 = in sync, 2 = DRIFT (alert), 1 = error"
```

Notice you `apply` the *saved* plan, not a fresh one — so what's applied is exactly what
was reviewed. In the lab you wrap this in a workflow that plans on PRs, comments the diff,
applies on merge behind an environment gate, and runs the drift check nightly.

## 5. Hands-on lab

You'll run the `plan → review → apply` loop locally against a free `local`-provider
config, trigger and observe **drift**, then validate a full `terraform.yml`
(plan-on-PR with a PR comment, auto-apply to dev, gated apply to production, nightly drift)
with `actionlint`. Local and free; running it on GitHub with a cloud backend is an
optional, marked extension.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **Apply the saved plan.** Pass the `plan` artifact to `apply` so you apply exactly what
  was reviewed; re-planning at apply time can pick up changes nobody saw.
- **Remote state with locking.** Use a locking backend (S3+DynamoDB, GCS, TF Cloud);
  never keep state local or unlocked in CI.
- **Separate roles for plan vs apply.** Read-only for plan (PR-safe), write for apply.
  Never let a fork PR's plan job hold write credentials.
- **Gate by environment and blast radius.** Auto for dev; required reviewers (and
  `main`-only, wait timers) for staging/prod.
- **Drift is an alert, not a log line.** Route the nightly non-empty plan to a channel a
  human watches; decide whether to reconcile or codify the change.
- **Scope the scan gates sensibly.** `tfsec`/`checkov` should block on real misconfig; curate
  exceptions explicitly rather than disabling the gate.
- **Consider Atlantis at scale.** If you're copying the same workflow into dozens of repos,
  a central Terraform automation service may be worth operating.

## 7. Common mistakes

- **Applying without reviewing a plan** — merge straight to `apply`, surprises in prod.
  *Fix:* plan on PR, comment it, require approval; apply the saved plan.
- **Plan job with write credentials** — a fork PR can run code with mutate rights.
  *Fix:* read-only role for plan; write only for apply after merge + gate.
- **No state locking / no concurrency group** — two applies corrupt state. *Fix:* locking
  backend plus `concurrency` keyed to the environment, `cancel-in-progress: false`.
- **Stored cloud keys in secrets** — long-lived, high-privilege, leakable. *Fix:* keyless
  OIDC with least-privilege roles.
- **No drift detection** — console changes diverge silently for weeks. *Fix:* a scheduled
  `plan -detailed-exitcode` that fails loud on exit 2.
- **Same gate for dev and prod** — either dev is annoyingly slow or prod is dangerously
  open. *Fix:* auto for dev, required reviewers for prod.
- **Ignoring `apply` failures mid-change** — partial apply leaves infra inconsistent.
  *Fix:* locking, retries with the same plan, and alerting; never swallow the error.

## 8. Assessment

**Knowledge checks**

1. Why post the `terraform plan` output as a PR comment instead of just running it?
2. How do you gate dev vs production applies differently, and with what mechanism?
3. What does `terraform plan -detailed-exitcode` return, and how do you use it for drift?
4. Why should the plan job and the apply job have *different* cloud permissions?
5. What two mechanisms prevent two CI applies from corrupting state?

**Concept exercise**

> Explain how a team safely changes shared infrastructure through code review **without
> using the words "Terraform," "plan," or "apply."** Describe what a reviewer sees, what
> happens on approval, and how you'd notice if reality later drifted from the agreed state.

**Trade-off / debugging exercise**

> An IaC pipeline stores a cloud admin key as a secret and uses it for both the PR plan
> job and the merge apply job. There's no environment gate (prod applies automatically on
> merge), no state locking, and no scheduled plan. A contributor opens a PR from a fork, and
> two PRs merge within the same minute. List four things that can go wrong and the specific
> fix for each.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** So a human reviews the concrete diff (what will actually change) attached to the
  PR, not just the HCL — the plan is the review artifact.
- **Q2:** dev applies automatically on merge; staging/production use a GitHub Environment
  with required reviewers (and optionally wait timers and `main`-only deployment branches)
  so the job pauses for approval.
- **Q3:** `0` = no changes, `2` = non-empty plan (drift), `1` = error. Run it on a schedule
  and fail loud / alert on exit `2`.
- **Q4:** Plan only previews, so it needs read-only — and PR plan jobs can run untrusted
  fork code; only apply needs write. Splitting roles stops a PR from mutating anything.
- **Q5:** A locking remote backend (one writer at a time) and a GitHub `concurrency` group
  keyed to the environment with `cancel-in-progress: false`.
- **Debugging:** (1) Admin key as a secret → keyless OIDC, least privilege. (2) Same role
  for plan and apply + fork PR → read-only plan role, write only on apply. (3) Auto prod
  apply → environment gate with required reviewers. (4) Two simultaneous merges, no locking
  → locking backend + concurrency group; add the nightly drift plan too.

</details>

## 9. Further reading

- HashiCorp — [Automate Terraform with GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- HashiCorp — [`setup-terraform` action](https://github.com/hashicorp/setup-terraform) and [state locking](https://developer.hashicorp.com/terraform/language/state/locking)
- Runatlantis — [Atlantis: Terraform pull request automation](https://www.runatlantis.io/)
- Aqua Security — [tfsec](https://aquasecurity.github.io/tfsec/) · Bridgecrew — [Checkov](https://www.checkov.io/)
- GitHub — [Configuring OpenID Connect in cloud providers](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- Gruntwork — [How to manage Terraform state and CI/CD](https://docs.gruntwork.io/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 06.5 — Container Build Pipelines](../05-container-build-pipelines/) · _Next:_ [Phase 7 — Kubernetes Package Management](../../07-kubernetes-package-management/)
