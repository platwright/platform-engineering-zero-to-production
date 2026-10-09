# Cloud Account Setup (Google Cloud)

The course uses **Google Cloud (GKE)** as its primary platform. The concepts are
provider-agnostic — AWS and Azure appear as optional references — but the hands-on
cloud labs target GCP.

> **You can defer this.** Phases 00–03 and much of the early curriculum run
> **entirely locally** (Docker + kind). You only need cloud from **Infrastructure
> as Code / Project 1** onward. That said, setting up **billing alerts** now takes
> five minutes and protects you from surprises later.

> 💸 **The golden rule of cloud labs:** *provision, learn, and **tear down**.*
> Cloud resources cost money for as long as they exist. Every build lab ends with a
> cleanup step — do it. The cleanest teardown of all is to **delete the whole
> project** when you're done with a phase.

---

## 1. Create an account and get free credit

1. Go to <https://cloud.google.com/> and sign up (or sign in).
2. New accounts include **free trial credit** and an **Always Free** tier. The
   labs are designed to fit within a small budget.
3. You'll be asked for a payment method. This is normal; you won't be charged
   beyond your budget if you set alerts (step 3) and tear resources down.

---

## 2. Create a dedicated project

Use a **separate project** for this course so you can track its cost in isolation
and delete everything at the end by deleting the project.

**Console:** open the [project
picker](https://console.cloud.google.com/projectselector2/home/dashboard) →
**New Project** → name it e.g. `platform-course`.

**CLI** (after installing `gcloud` — see
[`environment-setup.md`](./environment-setup.md)):

```bash
# Pick a globally-unique project ID (lowercase, digits, hyphens)
export PROJECT_ID="platform-course-$(date +%s)"

gcloud projects create "$PROJECT_ID" --name="Platform Course"
gcloud config set project "$PROJECT_ID"
```

Link it to your billing account:

```bash
# List your billing accounts to find the ID (format: XXXXXX-XXXXXX-XXXXXX)
gcloud billing accounts list

export BILLING_ACCOUNT_ID="XXXXXX-XXXXXX-XXXXXX"
gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT_ID"
```

---

## 3. Set a budget and alerts (do this first!)

This is the single most important step. A budget doesn't *cap* spending, but it
**emails you** as you approach your limit — your early-warning system.

**Console (recommended):** [Billing → Budgets &
alerts](https://console.cloud.google.com/billing/budgets) → **Create budget** →
scope to your project → set an amount (e.g. **$50**) → set alert thresholds at
**50%, 90%, 100%**.

**CLI:**

```bash
gcloud billing budgets create \
  --billing-account="$BILLING_ACCOUNT_ID" \
  --display-name="platform-course-budget" \
  --budget-amount=50USD \
  --threshold-rule=percent=0.5 \
  --threshold-rule=percent=0.9 \
  --threshold-rule=percent=1.0
```

> Prefer a **low budget** (you can raise it). If you blow through $50 on a learning
> lab, something was left running — investigate immediately.

---

## 4. Initialize and authenticate the CLI

```bash
gcloud init                 # choose your account and the course project
gcloud auth application-default login   # credentials for Terraform & SDKs
gcloud config get-value project         # confirm the right project is active
```

---

## 5. Enable APIs as you need them

You don't need to enable everything now — each module enables what it uses. When a
lab needs an API, you'll run something like:

```bash
# Examples you'll meet later (don't run them all now):
gcloud services enable container.googleapis.com      # GKE
gcloud services enable compute.googleapis.com        # VMs, networking, LBs
gcloud services enable artifactregistry.googleapis.com
gcloud services enable secretmanager.googleapis.com
```

---

## 6. IAM & credential hygiene

The habits you build here are the habits you carry to production. Read
[SECURITY.md](../SECURITY.md) too.

- **Least privilege.** Grant only the roles a task needs. Avoid `Owner`/`Editor`
  for automation.
- **Prefer keyless auth.** Where the course offers it (CI/CD with GitHub Actions),
  use **Workload Identity Federation / OIDC** instead of downloading long-lived
  service-account JSON keys.
- **If you must create a service-account key**, treat the JSON file as a secret:
  never commit it. The repo's [`.gitignore`](../.gitignore) already excludes
  `credentials*.json` and `sa-key*.json`, but think before `git add`.
- **Rotate and delete** credentials when you're done with them.

---

## 7. Choosing a cheap region

Pick one region and stick with it to minimize cross-region egress. `us-central1`
is a common, low-cost default used in examples. Where labs allow it, prefer
**spot/preemptible** VMs and **scale dev clusters to zero** when idle — these are
core FinOps habits taught later.

---

## 8. Cleanup / teardown

Every build lab has a cleanup step. In addition, at the end of a phase you can
remove *everything* by deleting the project:

```bash
# Nuclear option — removes all resources in the project
gcloud projects delete "$PROJECT_ID"
```

For individual labs, the module's `lab/README.md` lists the precise
`terraform destroy` / `kubectl delete` / `gcloud ... delete` commands.

> **Habit to build:** after any cloud lab, open [Billing →
> Reports](https://console.cloud.google.com/billing/reports) and confirm your
> spend is trending the way you expect.

---

## Ready?

- Local-only modules (00–03) need nothing above — you can start now.
- When you reach [Infrastructure as Code](../05-infrastructure-as-code/), come
  back and make sure steps 1–4 are done and a **budget alert** is set.

Next: choose your path in [`learning-path.md`](./learning-path.md), or begin
[**01 · Platform Foundations →**](../01-platform-foundations/).
