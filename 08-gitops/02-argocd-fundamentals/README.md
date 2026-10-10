# Module 08.2 — Argo CD Fundamentals

> Argo CD is the production version of the reconcile loop you built by hand in the
> last module: an in-cluster controller that pulls declarative config from Git and
> continuously reconciles the cluster toward it. This module covers its
> architecture, the `Application` resource, and the health/sync model you'll live in
> every day.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 08.1 — GitOps Principles](../01-gitops-principles/), a local kind cluster, and `kubectl` from [`00-orientation`](../../00-orientation/environment-setup.md).

## Learning objectives

By the end of this module you will be able to:

- Describe Argo CD's **core components** and how a sync flows through them.
- Author an **`Application`** resource: source, destination, and sync policy.
- Distinguish **health status** from **sync status**, and read both correctly.
- Configure **sync options** — automated sync, `prune`, `selfHeal`,
  `CreateNamespace` — and know what each one risks.
- Drive Argo CD declaratively and with the **CLI**, and reason about RBAC and
  notifications.

---

## 1. Concept

### What Argo CD is

Argo CD is a declarative, GitOps continuous-delivery controller for Kubernetes. You
hand it the location of some manifests in Git (plain YAML, a Helm chart, or a
Kustomize overlay) and a target cluster/namespace; it renders them, compares the
result to what's live, and reconciles. It is the hand-built loop from Module 08.1,
made correct: it assesses health, prunes safely, orders resources, exposes a UI and
API, and enforces RBAC.

### Architecture

Argo CD is a handful of cooperating components, all running *inside* the cluster:

- **API server.** Serves the gRPC/REST API that the web UI and `argocd` CLI use, and
  enforces authentication, RBAC, and the app management operations.
- **Repository server (repo-server).** Clones Git repos and **renders** the final
  manifests — runs `helm template`, `kustomize build`, or reads plain YAML — then
  hands the result to the controller. It holds no cluster state; it's a manifest
  factory and cache.
- **Application controller.** The heart of the loop. It compares the rendered
  desired state against live cluster state, computes `OutOfSync`/`Healthy`, and
  performs syncs. This is the reconciliation engine.
- **Dex (optional).** An identity broker for SSO (OIDC/SAML/LDAP). You can also wire
  OIDC directly and skip Dex.
- **Redis.** A cache for rendered manifests and computed state. It's disposable —
  losing it just forces recomputation.

```text
   Git repo ──clone/render──►  repo-server ──manifests──►  application controller
   (desired state)                                               │
                                                                 │ compare + sync
        UI / argocd CLI ──► API server ──(RBAC)──► controller ───▼──► target cluster
                                   ▲                                  (live state)
                                   └── Dex/OIDC (SSO)   Redis (cache)
```

Everything flows toward the **application controller**, which is the only component
that reconciles live state — just like the API server was the hub in the Kubernetes
architecture you studied in Phase 3.

### The Application resource

An **`Application`** is a custom resource that defines one reconciliation unit: *this
source* should be made live in *this destination* using *this sync policy*.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd            # Applications live in the argocd namespace
spec:
  project: default
  source:                      # WHERE desired state comes from
    repoURL: https://github.com/argoproj/argocd-example-apps
    targetRevision: HEAD       # a branch, tag, or commit — pin this in prod
    path: guestbook            # folder (or chart) within the repo
  destination:                 # WHERE it should run
    server: https://kubernetes.default.svc   # the in-cluster API
    namespace: guestbook
  syncPolicy:
    automated:                 # omit this block for manual sync
      prune: true              # delete resources removed from Git
      selfHeal: true           # revert out-of-band drift
    syncOptions:
      - CreateNamespace=true   # make the namespace if it doesn't exist
```

Three parts carry the meaning: **source** (what to deploy and from where),
**destination** (which cluster and namespace), and **syncPolicy** (how reconciliation
behaves). The same `source` block can point at a Helm chart (`source.helm`) or a
Kustomize overlay — Argo CD detects and renders each.

### Health status vs sync status — two different questions

New users conflate these; they answer different questions, and reading them wrong
sends you debugging the wrong thing.

- **Sync status** answers: *does live state match Git?*
  - **Synced** — the cluster matches the rendered manifests.
  - **OutOfSync** — it doesn't (someone drifted it, or Git moved ahead).
- **Health status** answers: *are the running resources actually healthy?*
  - **Healthy** — resources are up and ready (Deployment available, Service has
    endpoints).
  - **Progressing** — still rolling out.
  - **Degraded** — failed (crash-looping Pods, failed rollout).
  - **Missing** — declared in Git but not present in the cluster.
  - **Unknown** — Argo CD can't determine health.

They are independent. An app can be **Synced + Degraded** (Git matches the cluster,
but the image crash-loops — a *code* problem) or **OutOfSync + Healthy** (it's
running fine, but Git has a newer version not yet applied — a *delivery* problem).
Knowing which pair you're looking at tells you whether to fix the app or run a sync.

### Sync options you must understand

- **`automated`** — reconcile automatically on drift/new commits. Omit it and sync
  is manual (a human or pipeline triggers it) — common for production gates.
- **`prune`** — delete live resources that were removed from Git. Powerful and
  dangerous; off by default so a bad render can't wipe resources.
- **`selfHeal`** — revert out-of-band changes back to Git. This is your drift
  defense.
- **`CreateNamespace=true`** — create the destination namespace automatically.
- **`replace`** — use `kubectl replace` instead of `apply` for resources that can't
  be patched. A last resort.

### Repository types and the CLI

A `source` can be **Git** (plain YAML, Helm, or Kustomize), a **Helm** repository,
or an **OCI** registry (the artifacts you packaged in Phase 6). Day to day you'll
drive Argo CD declaratively (commit `Application` manifests) and inspect it with the
CLI: `argocd app list`, `argocd app get <name>`, `argocd app sync <name>`,
`argocd app history <name>`, and `argocd app rollback <name> <id>`.

---

## 2. Why it matters for platform engineering

Argo CD is, for most platforms, *the* delivery control plane — the thing every team
ships through:

- **It's the paved road for delivery.** Teams get continuous, auditable deployment
  without learning cluster credentials or `kubectl`. Their interface is a pull
  request; Argo CD does the rest.
- **It centralizes delivery policy.** Health checks, prune/self-heal behavior,
  sync windows, and RBAC are configured once by the platform team and inherited by
  every app.
- **It makes multi-tenancy real.** Argo CD **Projects** scope which repos, clusters,
  and namespaces a set of Applications may touch — so Team A can't deploy into Team
  B's namespace. That boundary is a platform responsibility.
- **It's the substrate for everything next.** ApplicationSets (08.3), promotion
  (08.4), and secrets (08.5) all build on the `Application`. Project 2 is essentially
  "operate Argo CD well for many teams."

---

## 3. Mental model

Picture Argo CD as the Module 08.1 loop with real organs bolted on. The controller
is the loop; the repo-server renders desired state; the API server guards the door.

```text
            ┌──────────────────────────────────────────────┐
            │   Git repo  —  DESIRED STATE (per Application) │
            └───────────────────────┬──────────────────────┘
                                    │ repo-server renders (helm/kustomize/yaml)
                                    ▼
   ┌───────────────┐   compare     ┌───────────────────────────┐
   │  Live cluster │ ◄──────────── │   application controller   │
   │  ACTUAL state │ ──────────────►│  sync status + health     │
   └──────┬────────┘    observe    └─────────────┬─────────────┘
          │                                      │ sync if OutOfSync
          └──────────────────────────────────────┘
                   one Application = one reconcile unit
```

Three rules to remember:

1. **One `Application` is one reconcile unit** mapping a Git source to a cluster
   destination.
2. **Sync status ≠ health status.** "Matches Git" and "actually works" are different
   questions.
3. **`prune` and `selfHeal` are the sharp edges.** Self-heal protects you; prune can
   delete — enable each deliberately.

---

## 4. Minimal implementation

The smallest useful Argo CD setup is: install it, then apply one `Application`
manifest. No UI clicking required — the `Application` is itself declarative GitOps.

```bash
# Install Argo CD from the upstream manifests (free, local kind cluster).
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server --timeout=180s
```

```bash
# Declare one Application and let the controller reconcile it.
kubectl apply -f - <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: guestbook
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [ CreateNamespace=true ]
YAML

kubectl -n argocd get applications          # watch SYNC STATUS and HEALTH columns
```

That's the whole model: desired state is a public Git repo; the `Application` is the
reconcile unit; the controller drives the cluster to **Synced + Healthy**. The lab
turns this into a guided exercise with drift and the CLI.

---

## 5. Hands-on lab

You'll install Argo CD on kind, deploy the public guestbook app as an auto-syncing
`Application`, watch self-heal revert drift, promote a change by editing the
`Application`, and use the `argocd` CLI to inspect sync status, health, and history.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **High availability.** The upstream `install.yaml` is non-HA. Production uses the
  HA manifests (replicated controller shards, redis-ha) and enough repo-server
  replicas to render all your apps without queueing.
- **SSO and RBAC.** Wire OIDC/SSO and define Argo CD RBAC so teams see and sync only
  their own apps. Never share the local `admin` account beyond bootstrap.
- **Projects for tenancy.** Use `AppProject` to whitelist source repos, destination
  clusters/namespaces, and allowed resource kinds per tenant. This is how you stop
  one team's Application from touching another's namespace.
- **Sync windows.** Configure windows to block (or allow) syncs during change
  freezes or business hours, especially for production.
- **Notifications.** Enable argocd-notifications to post to Slack/email on sync
  failure, health degradation, or sustained drift — a silent controller is a hidden
  outage.
- **Pin revisions.** `targetRevision: HEAD` is fine for demos; in production pin to a
  branch you control or a tag/commit so a random upstream push can't change prod.
- **Resource scale.** The repo-server CPU/memory and the controller's reconcile
  concurrency must be tuned as app count grows; watch sync latency.

---

## 7. Common mistakes

- **Confusing OutOfSync with Degraded.** Chasing a "broken app" that is actually
  Synced-but-Degraded (a code/image problem), or syncing an app that is merely
  OutOfSync-but-Healthy. *Fix:* read both statuses first and treat them as separate
  questions.
- **Enabling `prune` blindly, then losing resources.** A bad render or a wrong path
  can delete live resources. *Fix:* adopt prune deliberately, start without it, and
  use Argo CD's prune preview / `prune=false` dry runs.
- **Leaving `selfHeal` off and wondering why drift persists.** Without it, manual
  `kubectl edit` sticks and Git stops being authoritative. *Fix:* enable self-heal
  for anything you want Git to own.
- **Managing apps by clicking the UI.** Creating Applications in the UI makes the
  Applications themselves non-GitOps. *Fix:* commit `Application` manifests (and use
  app-of-apps / ApplicationSets from Module 08.3).
- **Using the `admin` account for everything.** Convenient and unaccountable. *Fix:*
  disable or rotate `admin` after bootstrap and use SSO with scoped RBAC.
- **`targetRevision: HEAD` in production.** An unrelated upstream commit can change
  your cluster. *Fix:* pin to a controlled branch, tag, or commit.

---

## 8. Assessment

**Knowledge checks**

1. Name Argo CD's core components and say which one performs reconciliation.
2. What are the three required parts of an `Application` `spec`?
3. An app shows **Synced + Degraded**. What does that tell you, and where do you
   look?
4. What does `selfHeal` do, and how does it differ from `prune`?
5. Why is creating Applications through the UI an anti-pattern for GitOps?

**Concept exercise**

> Explain what an Argo CD `Application` is **without using the words "Argo CD" or
> "controller."** Describe it as a mapping and a loop, so someone could recognize the
> concept in any GitOps tool.

**Trade-off / debugging exercise**

> You enable `automated: { prune: true, selfHeal: true }` on a production app. On-call
> scales it up during an incident and it snaps back; later a bad PR removes a
> resource from Git and it vanishes from the cluster. Explain *why each happened* and
> propose a policy (sync options, sync windows, manual gate) that keeps safety during
> normal operations but allows a controlled emergency override.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** API server, repo-server, application controller, (optional) Dex, and
  Redis. The **application controller** reconciles.
- **Q2:** `source`, `destination`, and `syncPolicy` (project is also required but
  defaults to `default`).
- **Q3:** Live state *matches Git* (Synced) but the resources are *failing*
  (Degraded) — so it's an application/image problem (e.g. crash loop), not a delivery
  problem. Look at Pod logs/events, not at Git.
- **Q4:** `selfHeal` reverts out-of-band drift back to Git; `prune` deletes live
  resources that were removed from Git. One restores declared state; the other
  removes undeclared state.
- **Q5:** The Applications themselves become imperative, unversioned, and
  unreviewable — they should be declared in Git like everything else.
- **Debugging:** self-heal reverted the manual scale (drift); prune deleted the
  resource the PR removed (desired state changed). A safer policy: keep self-heal on
  but gate production with manual sync or sync windows, require review on the config
  repo, and for emergencies temporarily disable auto-sync (or use an override
  window) then reconcile Git back to reality.

</details>

---

## 9. Further reading

- Argo CD — [Core concepts](https://argo-cd.readthedocs.io/en/stable/core_concepts/)
  and [Architecture](https://argo-cd.readthedocs.io/en/stable/operator-manual/architecture/)
- Argo CD — [`Application` specification](https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/)
- Argo CD — [Automated sync, prune, and self-heal](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)
- Argo CD — [Resource health](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/)
  and [RBAC](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/)
- Argo CD — [Getting started](https://argo-cd.readthedocs.io/en/stable/getting_started/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [08.1 — GitOps Principles](../01-gitops-principles/)
· _Next:_ [08.3 — Argo CD ApplicationSets →](../03-argocd-applicationsets/)
