# ADR-004 — Why Kyverno for policy

## Status

Accepted
Date: 2026-10-09

## Context

Pod hardening (non-root, read-only root filesystem, dropped capabilities, signed
images, required labels) must be **structural** — enforced automatically — not left
to each team remembering to set the right fields. This needs an admission-control
policy engine. The two leading Kubernetes-native options are Kyverno and OPA
Gatekeeper.

Constraints: the platform team and its customers mostly know YAML, not a
specialized policy language; we want low adoption friction and good built-in support
for mutation and image-signature verification.

## Decision

We will use **Kyverno** as the policy-as-code engine for this foundation.

## Consequences

- **Easier:** policies are written in YAML/Kubernetes-native resources — no new DSL
  for the team to learn; Kyverno supports validate, **mutate**, and generate, plus
  image-signature verification, which fits our supply-chain goals.
- **Easier:** policy reports and an `Audit` vs `Enforce` mode make rollout safe
  (observe first, enforce second).
- **Harder / trade-offs:** for very complex logic, a general policy language (Rego)
  can be more expressive; Kyverno is another controller to operate and keep healthy.
- Enforced in Pass 2; in Pass 1 we hand-write hardened manifests and rely on review.

## Alternatives considered

- **OPA / Gatekeeper (Rego)** — extremely powerful and widely adopted, but Rego is a
  separate language that raises the learning curve for policy authors. We prefer
  Kyverno's YAML-native model for lower friction and its first-class mutation and
  image-verification features.
- **Pod Security Admission (built-in)** — good baseline for pod security levels, but
  less flexible than Kyverno for custom rules (labels, signatures, registries). We
  use PSA concepts as a floor and Kyverno for the rest.

## References

- [Kyverno documentation](https://kyverno.io/docs/)
- [Phase 13 · Security and Policy Engineering](../../../../13-security-and-policy-engineering/)
