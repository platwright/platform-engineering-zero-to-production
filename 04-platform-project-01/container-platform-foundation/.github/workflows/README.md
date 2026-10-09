# CI pipeline — Pass 2 (build → scan → sign → push)

> 🚧 **Pass 2, and a reference template.** This folder holds the project's target CI
> pipeline. You build and understand it in
> **[Phase 5 · CI/CD](../../../../06-cicd-for-platform-teams/)**.
>
> ⚠️ Note: GitHub only runs workflows from the **repository root** `.github/workflows/`.
> This nested copy is a teaching reference, not an active workflow. When you adopt
> it for a real service, the workflow lives in *that service's* repository root.

## What the pipeline must do (project requirements #4 and #5)

```text
lint → build → scan (Trivy) → sign (Cosign, keyless via OIDC) → push by digest
                     │
                     └─ block the build if CRITICAL CVEs are found
```

- **No long-lived cloud credentials** — authenticate with OIDC (keyless).
- **Immutable promotion** — the exact image (by digest) moves dev → prod.
- **Signed images** — so the cluster can later verify signatures (Kyverno, Phase 13).

See [`container-ci.yml`](./container-ci.yml) for an annotated reference you'll
complete in Phase 5. Security hardening of the pipeline itself (pinning actions by
SHA, minimal permissions) is covered there too.
