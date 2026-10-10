# ADR-014 — Why External Secrets Operator over committing secrets

## Status

Accepted
Date: 2026-10-10

## Context

GitOps makes Git the source of truth for cluster state — but secrets (database
passwords, API keys) must **not** sit in Git in plaintext, and Kubernetes `Secret`
objects are only base64-encoded, not encrypted. A GitOps platform needs a secrets
strategy that keeps the declarative, reconciled model while keeping secret *values*
out of Git. The common options are Sealed Secrets, SOPS, Vault Agent/CSI, and the
External Secrets Operator (ESO).

Constraints: GCP is the primary cloud (GCP Secret Manager is available); we want a
single, auditable source of truth for secrets, declarative references in Git, and a
pattern that works across backends and clouds.

## Decision

We will use the **External Secrets Operator (ESO)** with **GCP Secret Manager** as
the secret store. Git holds only a declarative `ExternalSecret` that *references* a
secret by name; ESO materializes the actual `Secret` in the cluster.

## Consequences

- **Easier:** the source of truth for secret *values* is a hardened, audited secret
  manager; Git holds only references, so the GitOps model is preserved with no
  plaintext secrets committed.
- **Easier:** backend-agnostic (Vault, AWS/GCP/Azure managers) and rotation-friendly —
  update the value in the manager and ESO propagates it.
- **Harder / trade-offs:** another operator to run and monitor; secrets still land as
  Kubernetes `Secret`s in-cluster, so encryption-at-rest (KMS) and tight RBAC on
  Secrets remain necessary; there is sync latency to consider for rotation.

## Alternatives considered

- **Sealed Secrets** — encrypts secrets so the *encrypted* blob can live in Git;
  simple and fully GitOps-native, but the source of truth becomes the sealed blob in
  Git (weaker rotation/audit than an external manager). A good lightweight choice.
- **SOPS (+ KMS)** — encrypts values in files committed to Git; great for small
  teams, but key management and decryption-in-cluster add moving parts.
- **Vault Agent / CSI** — powerful (dynamic, leased secrets) but heavier to operate;
  ideal when you already run Vault and need dynamic credentials.
- **Plaintext/base64 `Secret`s in Git** — rejected: base64 is not encryption.

This mirrors [Project 1's ADR-005](../../../../04-platform-project-01/container-platform-foundation/architecture/decisions/ADR-005-why-external-secrets-operator.md);
here it is specifically about keeping secrets out of the GitOps config repo.

## References

- [External Secrets Operator](https://external-secrets.io/)
- [Argo CD — Secret Management](https://argo-cd.readthedocs.io/en/stable/operator-manual/secret-management/)
