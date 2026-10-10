# Platform — Pass 2 manifests

> 🚧 These manifests are **not synced in Pass 1.** They depend on CRDs installed by
> later-phase components (Kyverno, External Secrets Operator) and are isolated here
> so the Pass 1 platform Application (which uses `directory.recurse: false`) ignores
> them.

Enable them in **Pass 2**, once you've installed the relevant operators (Phase 10),
by pointing an ArgoCD Application at this folder (or moving a manifest up into
`../`).

| File | What it does | Needs |
|------|--------------|-------|
| [`kyverno-verify-images.yaml`](./kyverno-verify-images.yaml) | Admits only Cosign-signed images from the allowed registry | Kyverno installed |
| [`eso-example.yaml`](./eso-example.yaml) | Syncs a secret from GCP Secret Manager into a `Secret` | External Secrets Operator + GCP |

See [Phase 10 · Security and Policy Engineering](../../../../../13-security-and-policy-engineering/)
and [ADR-014](../../../architecture/decisions/ADR-014-secrets-strategy.md).
