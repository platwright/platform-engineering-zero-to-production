# Lab — Classify platform pipelines and write a fail-loud policy

> You'll do a platform engineer's first CI/CD job: read a messy, "it technically
> runs" workflow, **classify** each pipeline by type, hunt down the silent-skip
> anti-patterns that let it go green while actually failing, and write a one-page
> **fail-loud policy**. Then you'll validate a corrected validation pipeline locally
> with `actionlint`. Everything is local and free.

**Estimated time:** ~45–60 minutes
**Type:** discovery / design
**Deliverable:** A completed [`pipeline-review.md`](./pipeline-review.md) worksheet
(classification + anti-pattern findings + a fail-loud policy) and a locally validated
[`validation-pipeline.yml`](./validation-pipeline.yml).

## Objectives

- Classify jobs as infrastructure, configuration, or validation pipelines.
- Identify silent-skip anti-patterns (`|| true`, `continue-on-error`, dead branch
  conditions) that make a broken pipeline report success.
- Write a reusable fail-loud policy.
- Validate a workflow file locally with `actionlint`.

## Prerequisites

- The lesson [`../README.md`](../README.md).
- Everything from
  [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  (Git and a shell).
- **Optional but recommended:** [`actionlint`](https://github.com/rhysd/actionlint)
  for Step 4. It is free and local. Install with Go
  (`go install github.com/rhysd/actionlint/cmd/actionlint@latest`) or follow the
  project's [install guide](https://github.com/rhysd/actionlint/blob/main/docs/install.md).
  No GitHub account or cloud spend is required for this lab.

## Steps

1. **Read the messy workflow and classify each job.**

   The workflow below mixes all three pipeline types into one file — the first thing
   to fix. Open [`pipeline-review.md`](./pipeline-review.md) and, in Part A, write the
   type (infrastructure / configuration / validation) and real-world effect of each job.

   ```yaml
   name: platform   # a kitchen-sink workflow — do NOT copy this shape
   on:
     push:
     pull_request:
   jobs:
     scan:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - name: Trivy scan
           continue-on-error: true            # <-- smells wrong on a gate
           run: trivy fs --severity CRITICAL --exit-code 1 .
     package-chart:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - run: helm lint ./chart && helm package ./chart
         - run: helm push ./*.tgz oci://registry.example.com/charts || true  # <-- ?
     apply:
       runs-on: ubuntu-latest
       if: github.ref == 'refs/heads/legacy-main'   # <-- does this branch exist?
       steps:
         - uses: actions/checkout@v4
         - run: terraform init && terraform apply -auto-approve
   ```

2. **Hunt the silent-skip anti-patterns.**

   In Part B of the worksheet, list every place a failure could be hidden. There are
   at least three. For each, write *why* it manufactures false confidence. Hints:

   - What does `continue-on-error: true` do to a red step?
   - What does `|| true` do to a non-zero exit code?
   - If `legacy-main` doesn't exist, does the `apply` job run — and does the overall
     workflow still report success?

3. **Write a fail-loud policy.**

   In Part C, write 5–8 rules your team could adopt (gates must be able to fail the
   build; `apply` requires a reviewed plan and four-eyes; one pipeline does one job
   type; failures notify a human; drift is detected on a schedule). This one page is
   the most valuable artifact you'll produce today.

4. **Validate the corrected validation pipeline locally.**

   The file [`validation-pipeline.yml`](./validation-pipeline.yml) is a *clean*
   validation pipeline: cheap checks first, no silent skips, drift detection on a
   schedule. Lint it:

   ```bash
   actionlint validation-pipeline.yml
   ```

   Expect **no output and exit code 0** — the file is valid. Paste the result into
   Part D. (If you don't have `actionlint`, read the file and confirm by eye that no
   step uses `continue-on-error` or `|| true`, and that the drift job fails loudly on a
   non-empty plan via `terraform plan -detailed-exitcode`.)

## Expected result

- Part A classifies `scan` as validation, `package-chart` as configuration, and
  `apply` as infrastructure.
- Part B identifies at least three silent-skip hazards: `continue-on-error: true` on
  the scan, `|| true` on the chart push, and the dead-branch `if:` that makes `apply`
  a no-op while the workflow still reports success.
- Part C is a coherent one-page policy.
- `actionlint validation-pipeline.yml` prints nothing and exits 0.

## Cleanup

> This lab creates nothing in the cloud and spends nothing. Only local files are
> involved, so there is no teardown beyond optionally removing the linter.

```bash
# Optional: remove the actionlint binary if you installed it only for this lab.
# (Go installs it under your GOBIN / GOPATH/bin.)
rm -f "$(go env GOPATH)/bin/actionlint" 2>/dev/null || true
```

## Reflection

- Which single rule from your fail-loud policy would catch the most real-world
  incidents, and why?
- The `apply` job "passed" while doing nothing. Why is a check that silently does
  nothing more dangerous than a check that loudly fails?
- Splitting this file into three per-type workflows changes who must review each one.
  How would you set the required reviewers differently for the `apply` pipeline?

## Stretch goals (optional)

- Rewrite the messy workflow as **three** separate files (`validation.yml`,
  `chart-release.yml`, `infra-apply.yml`) and lint each with `actionlint`.
- Add a `concurrency:` group to the `apply` pipeline so two applies can't race (you'll
  learn the full mechanics in Module 06.2).
- Replace `|| true` on the chart push with a real failure path and a notification step,
  and explain what the pipeline now guarantees that it didn't before.
