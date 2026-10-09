# ADR-005 — Why External Secrets Operator

## Status

Accepted
Date: 2026-10-09

## Context

Workloads need secrets (database passwords, API keys), but secrets must **never**
live in Git or be baked into images. Kubernetes `Secret` objects are only
base64-encoded (not encrypted) by default. We need a way to keep the source of truth
in a proper secret store and sync it into the cluster safely, in a GitOps-friendly
way.

Constraints: GCP is the primary cloud (so GCP Secret Manager is available); we want
developers to reference a secret declaratively without ever handling the raw value;
and we want the pattern to work across secret backends.

## Decision

We will use the **External Secrets Operator (ESO)** to sync secrets from an external
store (GCP Secret Manager) into Kubernetes `Secret` objects.

## Consequences

- **Easier:** the source of truth stays in a hardened, audited secret store; teams
  declare an `ExternalSecret` referencing a key, and ESO materializes the `Secret` —
  no plaintext in Git, no manual `kubectl create secret`.
- **Easier:** backend-agnostic (Vault, AWS/GCP/Azure secret managers), so the
  pattern transfers across clouds.
- **Harder / trade-offs:** another operator to run; secrets still land as Kubernetes
  `Secret`s in the cluster (so encryption-at-rest / KMS and tight RBAC on secrets
  remain necessary); sync latency to consider for rotation.
- Introduced in Pass 2; Pass 1's sample app deliberately uses no secrets.

## Alternatives considered

- **Sealed Secrets** — encrypts secrets so they *can* be committed to Git;
  simple and GitOps-friendly, but the source of truth becomes the sealed blob in Git
  rather than a real secret store, and rotation/auditing is weaker. Good for small
  setups; we prefer ESO's external source of truth.
- **Vault Agent Injection** — powerful (dynamic secrets, leasing) but heavier to
  operate; a strong choice when you already run Vault and need dynamic credentials.
- **Raw Kubernetes Secrets in Git** — rejected: base64 is not encryption.

## References

- [External Secrets Operator](https://external-secrets.io/)
- [Phase 13 · Security and Policy Engineering](../../../../13-security-and-policy-engineering/)
