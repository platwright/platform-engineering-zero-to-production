# 04 · Platform Project 01 — Container Platform Foundation

> 🚧 **Status: planned.** This section is scaffolded — the full content is on the
> way. Track progress in the [ROADMAP](../ROADMAP.md) and [CHANGELOG](../CHANGELOG.md).

**Project 1**

Your first end-to-end project: build a production-grade GKE cluster foundation with the baseline capabilities a team needs to start deploying services safely.

## What you'll build

- GKE cluster, VPC, and node pools provisioned with Terraform
- Namespaces with per-team RBAC, LimitRanges, and ResourceQuotas
- A CI pipeline: build → Trivy scan → Cosign sign → push
- Policy enforcement (non-root, read-only) via Kyverno
- Secrets via External Secrets Operator + GCP Secret Manager

## Prerequisites

Work through [00 · Orientation](../00-orientation/) and [01 · Platform Foundations](../01-platform-foundations/) first. This project pulls together Containerization and Kubernetes Fundamentals.

## Want to help build this section?

Contributions are welcome. Start from the [module template](../shared/templates/module-template.md)
and read [CONTRIBUTING.md](../CONTRIBUTING.md).
