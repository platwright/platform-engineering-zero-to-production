# Lab — Build a workflow and authenticate keylessly with OIDC

> You'll build and validate a real GitHub Actions workflow that exercises triggers,
> contexts, job outputs, and concurrency — then author a **keyless** cloud
> authentication job that uses OIDC instead of a stored secret. The workflow-building
> and validation are fully local and free; actually running the keyless auth against
> a cloud is an optional, clearly-marked extension.

**Estimated time:** ~50–70 minutes
**Type:** build
**Deliverable:** A locally validated [`ci.yml`](./ci.yml) and a keyless
[`oidc-gcp.yml`](./oidc-gcp.yml) you can explain claim-by-claim.

## Objectives

- Validate workflow YAML locally with `actionlint`.
- Explain how contexts, job outputs, `needs`, and concurrency work.
- Configure keyless cloud authentication with `id-token: write` and a scoped trust.
- Articulate why keyless OIDC beats a long-lived stored secret.

## Prerequisites

- The lesson [`../README.md`](../README.md).
- Everything from
  [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md).
- [`actionlint`](https://github.com/rhysd/actionlint) installed (free, local):
  `go install github.com/rhysd/actionlint/cmd/actionlint@latest`.
- **Optional:** [`act`](https://github.com/nektos/act) to run `ci.yml` locally with
  Docker, and/or a scratch GitHub repository to run it on hosted runners (free tier).
- **Optional (Step 4 only):** a Google Cloud project on the **free tier**. See the
  cost note in that step before enabling anything.

## Steps

1. **Validate the anatomy workflow.**

   ```bash
   actionlint ci.yml
   ```

   Expect no output and exit code 0. Open [`ci.yml`](./ci.yml) and trace: the three
   triggers, the `concurrency` group, the `build` job's `outputs:`, and how the `test`
   job reads `needs.build.outputs.version`. Nothing persists between jobs *except* the
   output you deliberately passed.

2. **(Optional) Run it.**

   Run it locally with `act`, or push it to a scratch repo under
   `.github/workflows/ci.yml` and open the Actions tab:

   ```bash
   # Local, needs Docker:
   act pull_request -W ci.yml
   ```

   Watch the context values print, and confirm `test` starts only after `build`.
   Push a second commit quickly and watch `cancel-in-progress` supersede the first run.

3. **Read the keyless workflow and explain every claim.**

   Open [`oidc-gcp.yml`](./oidc-gcp.yml) and validate it:

   ```bash
   actionlint oidc-gcp.yml
   ```

   Answer, in your own words: Why does the job need `permissions: id-token: write`?
   What does GitHub put *inside* the OIDC token? What does Google check before handing
   back credentials, and how long do those credentials last? Note that there is **no
   `secrets.*` key anywhere** in this file — that's the point.

4. **(Optional, cloud) Make the keyless exchange real.**

   > **Cost & accounts note.** This step needs a Google Cloud project. Workload
   > Identity Federation and a service account are **free**, and the `gcloud auth list`
   > call costs nothing, but creating cloud resources always carries some risk of spend
   > — stay on the free tier and run the cleanup. You can skip this entire step and
   > still complete the lab; the deliverable is the validated, understood workflow.

   One-time setup (replace the placeholders, then update `oidc-gcp.yml`):

   ```bash
   PROJECT_ID="your-project"
   POOL="github"
   PROVIDER="github"
   REPO="your-org/your-repo"

   gcloud iam workload-identity-pools create "$POOL" \
     --project="$PROJECT_ID" --location=global --display-name="GitHub pool"

   gcloud iam workload-identity-pools providers create-oidc "$PROVIDER" \
     --project="$PROJECT_ID" --location=global --workload-identity-pool="$POOL" \
     --display-name="GitHub provider" \
     --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
     --attribute-condition="assertion.repository=='${REPO}'" \
     --issuer-uri="https://token.actions.githubusercontent.com"

   gcloud iam service-accounts create github-actions --project="$PROJECT_ID"
   ```

   Bind the service account to the pool for your repo, copy the provider resource name
   into `oidc-gcp.yml`, push the workflow, and run it. The `gcloud auth list` step
   proves you authenticated with **no stored key**. The `attribute-condition` is the
   trust boundary — only your repository's tokens are accepted.

5. **Compare the two worlds.**

   Write two or three sentences contrasting this keyless setup with the stored-secret
   alternative (`secrets.GCP_SA_KEY`): which is longer-lived, which is scoped, which
   survives a leak, and which one you'd ship on a platform.

## Expected result

- `actionlint ci.yml` and `actionlint oidc-gcp.yml` both exit 0 with no findings.
- You can explain contexts, outputs, `needs`, and concurrency from `ci.yml`.
- You can explain the OIDC claims and the `id-token: write` permission.
- (If you did Step 4) the workflow authenticates to GCP with no stored secret, and
  `gcloud auth list` shows an active, short-lived identity.

## Cleanup

> If you did the optional cloud step, delete everything you created. The federation
> primitives are free, but leave nothing lingering.

```bash
PROJECT_ID="your-project"
gcloud iam service-accounts delete \
  github-actions@"$PROJECT_ID".iam.gserviceaccount.com --project="$PROJECT_ID" --quiet || true
gcloud iam workload-identity-pools delete github \
  --project="$PROJECT_ID" --location=global --quiet || true
# Remove the scratch workflow from your repo if you pushed one.
```

## Reflection

- A stored cloud key is "just one secret." Why is removing it such a large security win
  for a *platform* pipeline specifically?
- The trust policy pins the repository. What would go wrong if it accepted any repo in
  the org, and how could an attacker abuse that?
- Where would an `environment: production` with a required reviewer slot into this
  workflow, and what would it change about who can deploy?

## Stretch goals (optional)

- Add a second job that targets `environment: production` and observe how a required
  reviewer pauses the run (configure the reviewer in repo settings).
- Tighten the trust `attribute-condition` further to a specific branch
  (`assertion.ref=='refs/heads/main'`) and explain the trade-off for PR workflows.
- Convert `ci.yml` to also emit a job summary with `$GITHUB_STEP_SUMMARY` and render
  the computed version there.
