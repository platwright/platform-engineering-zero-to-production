# Interview Prep — GitOps

> This domain tests whether you understand GitOps as a *reconciliation* model, not
> just "CI that runs `kubectl`." Interviewers probe drift detection, pull-based
> delivery, secrets, promotion, and rollback. Practice describing the control loop
> and the single-source-of-truth principle out loud before checking the answer.

## Principles

### Q: What is GitOps, and how does it differ from traditional CI/CD?

**What they're really asking:** Do you grasp pull-and-reconcile versus push?

In traditional CD the **pipeline pushes**: an external runner holds cluster
credentials and runs `kubectl`/`helm` to apply changes. In GitOps, **Git is the
single source of truth** for desired state, and an **in-cluster agent** (ArgoCD or
Flux) **continuously pulls** that state and **reconciles** the cluster to match it.
CI is unchanged — it still builds and tests — but delivery becomes a reconciliation
driven by a Git commit rather than an outbound push.

- Git becomes the audit log; every change is a reviewed, revertible commit.
- The cluster converges to Git and self-heals drift instead of trusting a one-time apply.

**Going deeper:** [08.1 · GitOps Principles](../08-gitops/01-gitops-principles/)

**Red flags:** "GitOps is just storing YAML in Git." Missing the continuous reconciliation and pull model.

### Q: What are the core GitOps principles?

**What they're really asking:** Can you recite the OpenGitOps model and explain each?

- **Declarative** — the whole system is described as desired state, not scripts.
- **Versioned and immutable** — that state lives in Git, so it is auditable and revertible.
- **Pulled automatically** — agents pull approved state from the source of truth.
- **Continuously reconciled** — controllers constantly observe and converge actual to desired.

**Going deeper:** [08.1 · GitOps Principles](../08-gitops/01-gitops-principles/)

### Q: Push-based versus pull-based delivery — why does GitOps prefer pull?

**What they're really asking:** Do you understand the security and drift implications?

With **push**, an external CI system holds powerful cluster credentials; if it is
compromised the blast radius is every cluster, and nothing corrects manual drift.
With **pull**, a least-privilege agent **inside** each cluster reconciles from Git, so
credentials never leave the cluster, drift is auto-corrected, and the model scales to
a fleet — each cluster simply pulls the state meant for it.

**Going deeper:** [08.1 · GitOps Principles](../08-gitops/01-gitops-principles/) and [08.2 · ArgoCD Fundamentals](../08-gitops/02-argocd-fundamentals/)

## ArgoCD mechanics

### Q: How does ArgoCD detect and resolve drift?

**What they're really asking:** Do you understand Argo as a reconciliation loop?

ArgoCD renders the **desired state** from Git (plain manifests, Helm, or Kustomize)
and continuously compares it to the **live state** in the cluster. When they differ
the Application is marked **OutOfSync** and Argo computes a diff. Behavior then
depends on configuration:

- **Manual sync** — Argo only reports drift; a human clicks or triggers sync.
- **Automated sync with self-heal** — Argo reapplies the desired state, reverting manual `kubectl` changes.
- **Prune** — resources deleted from Git are removed from the cluster.

It is the controller pattern again: observe desired versus actual, act to converge.

**Going deeper:** [08.2 · ArgoCD Fundamentals](../08-gitops/02-argocd-fundamentals/)

**Red flags:** Describing Argo as "it runs kubectl apply on a webhook." Missing continuous comparison and self-heal.

### Q: What is the App of Apps pattern, and how do ApplicationSets improve on it?

**What they're really asking:** Do you know how to manage many apps and clusters at scale?

**App of Apps** is a parent ArgoCD Application whose manifests are themselves child
Application resources, so one root app bootstraps and manages many. It works but is
boilerplate-heavy. **ApplicationSets** add a controller with **generators** — list,
cluster, Git directory/file, matrix, SCM — that **template** Applications
programmatically: one Application per cluster, per environment folder, or per team,
generated automatically. That is how you roll a change across a fleet without
hand-writing an Application for each target.

**Going deeper:** [08.3 · ArgoCD ApplicationSets](../08-gitops/03-argocd-applicationsets/)

### Q: What are sync waves and hooks?

**What they're really asking:** Do you know how to order dependent resources?

**Sync waves** order resource application within a sync using the
`argocd.argoproj.io/sync-wave` annotation, so lower-numbered resources (namespaces,
CRDs, databases) are applied and healthy before dependents. **Hooks**
(`PreSync`, `Sync`, `PostSync`, `SyncFail`) run Jobs at phases of the sync — database
migrations before the new version, smoke tests after. Together they let a single
sync respect real dependencies.

**Going deeper:** [08.2 · ArgoCD Fundamentals](../08-gitops/02-argocd-fundamentals/)

## Operating GitOps

### Q: How do you manage secrets in a GitOps model?

**What they're really asking:** Do you keep cleartext out of Git without breaking reconciliation?

Git must never hold a plaintext secret, so you store either an **encrypted blob** or a
**reference**:

- **Sealed Secrets** — encrypt a secret with the cluster's public key; the `SealedSecret` is safe in Git and a controller decrypts it in-cluster.
- **External Secrets Operator** — the real value lives in Vault or a cloud secrets manager; Git holds a reference, and the operator syncs it into a Kubernetes Secret.
- **SOPS** (with age or KMS) — values are encrypted in Git and decrypted at apply time (Flux integrates this natively).

**Going deeper:** [08.5 · Secrets in GitOps](../08-gitops/05-secrets-in-gitops/) and [13.4 · Secret Management](../13-security-and-policy-engineering/04-secret-management/)

**Red flags:** Base64 in a committed Secret (that is encoding, not encryption), or disabling reconciliation to "protect" secrets.

### Q: How do you promote a change from dev to production in GitOps?

**What they're really asking:** Do you promote an immutable artifact through environments via Git?

Each environment has its own desired state — typically Kustomize overlays or Helm
value files layered over a shared base. Promotion is a **Git change** that moves a
**tested image digest** from the dev config to staging to prod, almost always through
a **pull request** so prod gets review and policy gating. You promote the **same
immutable digest**, never rebuild per environment, so what you tested is exactly what
ships. ApplicationSets or a promotion tool can automate the mechanical parts.

**Going deeper:** [08.4 · Multi-Environment GitOps](../08-gitops/04-multi-environment-gitops/) and [07.3 · Kustomize](../07-kubernetes-package-management/03-kustomize/)

**Red flags:** Rebuilding the image per environment, or mutating prod directly with `kubectl` outside Git.

### Q: How do you roll back in GitOps?

**What they're really asking:** Do you understand that rollback is a Git operation?

Because desired state is versioned and immutable, rollback is a **`git revert`** (or
pointing the Application at the previous known-good commit or tag). The agent
reconciles the cluster back to that state deterministically — no snowflake, no manual
surgery. ArgoCD can also roll an Application back to a previously synced revision
directly.

**Going deeper:** [08.2 · ArgoCD Fundamentals](../08-gitops/02-argocd-fundamentals/)

### Q: How do you structure repositories for multi-environment GitOps?

**What they're really asking:** Do you keep one source of truth and avoid config sprawl?

- **Separate application source from deployment config** so app commits do not churn the environment state.
- Use a **base plus per-environment overlays** (Kustomize) or value files (Helm) so only the version and genuine differences vary between environments.
- Drive clusters and environments with **ApplicationSet generators** rather than copy-pasted Applications.
- Enforce that **no one hand-edits clusters** — self-heal will fight manual changes, which is the point.

**Going deeper:** [08.4 · Multi-Environment GitOps](../08-gitops/04-multi-environment-gitops/) and [09 · GitOps Platform project](../09-platform-project-02/gitops-platform/README.md)

### Q: What are the benefits and the failure modes of GitOps?

**What they're really asking:** Are you clear-eyed about the trade-offs, not a zealot?

Benefits: a full **audit trail**, deterministic **rollback**, automatic **drift
correction**, **least-privilege** delivery (the agent pulls), and self-service by pull
request. Failure modes to manage: **secret handling** adds moving parts; a heavy PR
process can make Git a **bottleneck**; **config sprawl** across overlays; and
reconciliation will **fight** any team that still edits clusters by hand, so you need
good repo RBAC and cultural buy-in.

**Going deeper:** [08.6 · GitOps Maturity Model](../08-gitops/06-gitops-maturity-model/)

**Red flags:** Claiming GitOps has no downsides, or ignoring secret management and promotion complexity.
