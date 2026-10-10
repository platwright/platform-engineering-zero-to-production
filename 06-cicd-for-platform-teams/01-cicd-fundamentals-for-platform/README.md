# Module 06.1 — CI/CD Fundamentals for Platform Teams

> Continuous integration and delivery are not new to you as an application
> developer. But when the thing you are shipping is the *platform itself* — clusters,
> shared charts, base images, IAM, and the pipelines other teams depend on — the
> rules change. This module reframes CI/CD from a platform team's point of view:
> what you are really changing, the three kinds of pipeline you will build, and a
> failure philosophy that refuses to fail quietly.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** [Phase 4 · Infrastructure as Code](../../05-infrastructure-as-code/) and
[Phase 2 · Containerization](../../02-containerization/) for context. No cloud; the lab is local.

## Learning objectives

By the end of this module you will be able to:

- Explain **why platform CI/CD differs from application CI/CD**, in blast-radius terms.
- Classify a pipeline as **infrastructure**, **configuration**, or **validation**.
- Describe the typical stages of each pipeline type (Terraform plan/apply; Helm
  lint/test/package/push; policy, drift, and security scans).
- State the **fail-fast, fail-loud, never-silently-skip** philosophy and why it is
  non-negotiable for platform changes.
- Reason about **change-review requirements** that differ for platform vs app changes.

---

## 1. Concept

### What is actually being changed?

Application CI/CD answers one question: *is this version of this service good enough
to ship?* The blast radius is one service. If it breaks, one team gets paged and
rolls back.

Platform CI/CD changes the ground every service stands on. A merge to the platform's
Terraform can resize a cluster, rewrite a network rule, or rotate an IAM role. A push
to a shared Helm chart or a base image flows into *every* team that depends on it. The
unit of change is small; the **blast radius is the whole estate**. That single fact
reshapes everything: how you review, how you gate, how you fail, and who gets to
approve.

```text
Application change            Platform change
─────────────────            ────────────────
one service                   the substrate every service runs on
one team rolls back           many teams affected at once
"did the tests pass?"         "what exactly will this do to prod, and who approved it?"
```

### Three kinds of platform pipeline

Nearly every pipeline a platform team owns is one of three types. Naming them helps
you design the right gates for each.

- **Infrastructure pipelines** change real cloud/cluster resources. The canonical
  shape is Terraform: `fmt → validate → plan → (review) → apply`. The `plan` is a
  preview of changes; `apply` makes them real. These are the highest-stakes pipelines
  because `apply` is often irreversible (you can't un-delete a database).
- **Configuration pipelines** package and publish *desired state* that something else
  will apply later. The canonical shape is a Helm chart: `lint → test (template /
  unit) → package → push` to a registry. Nothing in production changes when this runs
  — it produces a versioned artifact that a deploy or GitOps controller consumes.
- **Validation pipelines** change nothing and *assert* things are as they should be:
  policy checks (OPA/Conftest/Kyverno in CI), **drift detection** (a scheduled
  `terraform plan` that should be empty), security scans (Trivy, `tfsec`, `checkov`),
  and linters. They are the platform's smoke detectors.

```text
Infrastructure   plan → apply        mutates real resources      (highest stakes)
Configuration    build → publish     produces an artifact        (no prod change)
Validation       check → report      asserts, never mutates      (smoke detectors)
```

A useful rule: **a pipeline should do exactly one of these.** Mixing "apply
infrastructure" and "publish a chart" in one job makes the blast radius and the
required reviewers ambiguous.

### Fail fast, fail loud, never silently skip

Application pipelines can sometimes get away with a flaky step and a retry. Platform
pipelines cannot, because a *silent* failure means the platform's guarantees quietly
stopped being true — and nobody noticed until an incident.

Three rules:

- **Fail fast.** Order cheap, decisive checks first (`fmt`, `lint`, `validate`) so a
  broken change dies in seconds, not after a ten-minute build.
- **Fail loud.** A failed security gate or a non-empty drift plan must turn the build
  red and notify a human. Red is information.
- **Never silently skip.** The most dangerous pattern in platform CI is a check that
  is accidentally disabled: a `continue-on-error: true` left on a scanner, a gate that
  only runs on one branch, a `|| true` that swallows an exit code. A check that can be
  skipped without anyone noticing is worse than no check, because it manufactures false
  confidence.

### Review requirements differ

Because the blast radius differs, so does the bar for merging. An application change
might need one reviewer. A platform change that touches production infrastructure
typically needs: a reviewed **plan** attached to the PR, a **second approver**
(four-eyes), a protected environment, and often a named owner for the blast-radius
domain (networking, IAM). The pipeline's job is to *make the right review happen
automatically* — surface the plan, require the approval, and refuse to apply without it.

---

## 2. Why it matters for platform engineering

A platform's promise is "consume this and you get security, reliability, and speed by
default." Pipelines are how that promise is **kept mechanically** rather than hoped
for. If signing, scanning, and policy live in a pipeline every change must pass, then
"we sign our images" is a fact, not an aspiration.

The three-type taxonomy also tells you *where the danger is*. Infrastructure pipelines
need the strongest gates because `apply` is irreversible. Configuration pipelines are
safer (they only publish artifacts) but need provenance so you can trust what you
later deploy. Validation pipelines are cheap to run and catch the drift and CVEs that
would otherwise accumulate silently. Designing gates per type — instead of one
copy-pasted pipeline for everything — is a core platform skill.

Finally, this is the phase where the course's throughline becomes real. The container
pipeline (Module 06.5) and the Terraform pipeline (Module 06.6) are the engines of
Project 1 and Project 2. Everything here is in service of those two paved roads.

## 3. Mental model

Think of the three pipeline types as a **traffic system** with different controls for
different risks:

```text
            PLATFORM CI/CD — three roads, three sets of controls
            ───────────────────────────────────────────────────

  INFRASTRUCTURE ──► [ fmt ]→[ validate ]→[ plan ]═►(REVIEW GATE)═►[ apply ]
      (mutating)        fast cheap checks     preview    human + policy   real change
                                                         four-eyes, env gate

  CONFIGURATION  ──► [ lint ]→[ test ]→[ package ]→[ push to registry ]
      (artifact)      no production is touched; output is a versioned artifact

  VALIDATION     ──► [ scan / policy / drift-plan ] ──► RED if anything is wrong
      (assert)        runs on PRs and on a schedule; never mutates; always loud

  Rule of thumb:  mutation needs a gate · artifacts need provenance · asserts must be loud
```

If you remember one sentence: **classify the pipeline first, then choose gates to
match its blast radius — and never let a check fail quietly.**

## 4. Minimal implementation

You don't need GitHub Actions to feel the philosophy. A platform pipeline is, at its
core, an ordered list of checks where **any failure stops the line and is visible**.
Here is that idea as a plain shell script — fail-fast via `set -e`, fail-loud via a
non-zero exit, and *no* silent skips:

```bash
#!/usr/bin/env bash
set -euo pipefail   # -e fail fast, -u no undefined vars, -o pipefail no masked errors

echo "::group::validation"
terraform fmt -check         # cheap, decisive — runs first
terraform validate
tfsec .                      # security gate; a finding exits non-zero -> red
echo "::endgroup::"

echo "::group::plan"
terraform plan -out plan.tfplan   # preview only; mutates nothing
echo "::endgroup::"

# NOTE: no 'apply' here, and no '|| true' anywhere.
# A gate you can skip without noticing is worse than no gate.
```

The anti-pattern to internalize:

```bash
tfsec . || true          # <-- WRONG: swallows the exit code; failures vanish
continue-on-error: true  # <-- WRONG on a security gate: red becomes green
```

Both lines *look* harmless and are how platforms quietly lose their guarantees. The
whole of this phase is building this same ordered, loud, ungameable pipeline in
GitHub Actions.

## 5. Hands-on lab

You'll take a messy, "it technically runs" platform workflow and do a platform
engineer's first job: **classify** each pipeline by type, spot the silent-skip
anti-patterns, and write a one-page **fail-loud policy** your team could adopt. Then
you'll validate a corrected sample workflow locally with `actionlint`.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **One pipeline, one job type.** Keep infrastructure `apply`, artifact `publish`, and
  validation in separate workflows (or at least separate, independently gated jobs) so
  reviewers and permissions match the blast radius.
- **Least privilege per type.** A validation pipeline needs read-only credentials; an
  `apply` pipeline needs write. Don't hand every pipeline an admin role "to be safe" —
  that *is* the unsafe choice.
- **Drift detection is a first-class pipeline.** Schedule a nightly `plan`; a non-empty
  result means reality diverged from code. Alert on it, don't just log it.
- **Make red mean something.** Route pipeline failures to a channel a human watches,
  and treat a flaky platform pipeline as a bug to fix, not noise to mute — muted alarms
  are how silent failures hide.
- **Record who approved what.** For infrastructure changes, the approval trail (plan +
  approver + timestamp) is an audit artifact, not a nicety.
- **Idempotency and reruns.** Platform pipelines get re-run; design them so a second run
  is safe (plans are safe to repeat; applies must be guarded by state locking).

## 7. Common mistakes

- **Treating a platform change like an app change** — one reviewer, no plan attached,
  merge and hope. *Fix:* require a reviewed plan and four-eyes for anything that mutates
  shared infrastructure.
- **`continue-on-error` / `|| true` on a gate** — the build goes green while the check is
  actually failing. *Fix:* gates must be able to fail the build; only use
  `continue-on-error` for genuinely optional, informational steps, and say so explicitly.
- **One mega-pipeline that builds, publishes, and applies** — ambiguous blast radius and
  reviewers; a chart typo can block an urgent infra fix. *Fix:* separate by pipeline type.
- **No drift detection** — you believe prod matches code; it hasn't for weeks. *Fix:* a
  scheduled, alerting `plan`.
- **Slowest check first** — a ten-minute build runs before a one-second `fmt` that would
  have failed anyway. *Fix:* order checks cheap-and-decisive first (fail fast).
- **Giving pipelines standing admin credentials** — huge blast radius if the token leaks.
  *Fix:* least-privilege, short-lived credentials (keyless OIDC, Module 06.2).

## 8. Assessment

**Knowledge checks**

1. In blast-radius terms, how does a platform change differ from an application change?
2. Name the three platform pipeline types and give the canonical stages of each.
3. Which pipeline type is highest-stakes, and why?
4. What does "never silently skip" mean, and give two concrete anti-patterns that
   violate it.
5. Why might a production infrastructure change need a reviewed plan plus a second
   approver when an app change needs neither?

**Concept exercise**

> Explain the difference between an infrastructure pipeline and a configuration
> pipeline **without using the words "Terraform" or "Helm."** Describe what each one
> changes and when the real-world effect happens.

**Trade-off / debugging exercise**

> A teammate's platform workflow is green on every run, yet production has a critical
> CVE and the staging network rule never actually changed. You open the YAML and see
> `continue-on-error: true` on the Trivy step and an `apply` job with an `if:` that
> only matches a branch nobody uses. Explain what went wrong in failure-philosophy
> terms, and what you'd change.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** An app change affects one service; a platform change alters the shared
  substrate (clusters, networking, IAM, base images, shared charts), so a single merge
  can affect every team at once.
- **Q2:** Infrastructure (`fmt → validate → plan → apply`), configuration (`lint →
  test → package → push`), validation (`scan/policy/drift → report`).
- **Q3:** Infrastructure, because `apply` mutates real resources and is often
  irreversible (you can't un-delete data), so its gates must be strongest.
- **Q4:** It means no check may fail without turning the build red and notifying
  someone. Anti-patterns: `|| true` swallowing an exit code, and `continue-on-error:
  true` on a gate — both turn red into green.
- **Q5:** Because the blast radius is the whole estate and `apply` can be
  irreversible; a reviewed plan shows exactly what will change and four-eyes reduces
  the chance a destructive change merges unnoticed.
- **Debugging:** Both failures are *silent skips*. `continue-on-error` let a real CVE
  pass as green (fail-loud violated); the branch-scoped `if:` meant the apply never ran
  yet the pipeline still reported success (never-silently-skip violated). Fix: remove
  `continue-on-error` from the gate, correct the branch condition, and add an assertion
  that the apply actually executed (or fail the job if it was skipped).

</details>

## 9. Further reading

- GitHub — [Understanding GitHub Actions](https://docs.github.com/en/actions/learn-github-actions/understanding-github-actions)
- HashiCorp — [Automate Terraform with CI/CD](https://developer.hashicorp.com/terraform/tutorials/automation/automate-terraform)
- Helm — [Chart testing (`ct`)](https://github.com/helm/chart-testing) and [Charts guide](https://helm.sh/docs/topics/charts/)
- Aqua Security — [tfsec](https://aquasecurity.github.io/tfsec/) and [Trivy](https://trivy.dev/)
- Open Policy Agent — [Conftest](https://www.conftest.dev/) for policy checks in CI
- Google SRE — [Release Engineering](https://sre.google/sre-book/release-engineering/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Phase 4 · Infrastructure as Code](../../05-infrastructure-as-code/) · _Next:_ [Module 06.2 — GitHub Actions Deep Dive](../02-github-actions-deep-dive/)
