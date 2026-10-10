# Module 08.4 — Multi-Environment GitOps

> One environment is easy; the money is in **promoting the same change through dev →
> staging → prod safely and auditably.** This module covers the folder-over-branch
> strategy, promotion by pull request, sync waves for ordering, and rollback by Git
> revert — the workflow your platform offers every team.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 08.3 — ApplicationSets](../03-argocd-applicationsets/), Kustomize from [Phase 6](../../07-kubernetes-package-management/), and Argo CD on kind.

## Learning objectives

By the end of this module you will be able to:

- Choose a **folder-per-environment** layout and justify it over branch-per-environment.
- Run a **promotion workflow**: change an overlay → PR → review → merge → auto-sync.
- Order resource creation with **sync waves** (namespace before workload, CRDs
  before CRs).
- **Roll back** an environment by reverting a Git commit, and reason about rollback
  across environments.
- Decide where to **gate** production (manual sync, sync windows) while keeping lower
  environments fast.

---

## 1. Concept

### Folder strategy vs branch strategy

You have two ways to represent environments in Git, and the choice shapes
everything:

- **Branch per environment** — a `dev`, `staging`, and `prod` branch; promotion is a
  merge between branches. It sounds natural but rots quickly: branches **diverge**,
  cherry-picks get messy, and "what's different between staging and prod?" becomes a
  confusing branch diff rather than a config diff. You also can't see all
  environments at once.
- **Folder per environment** — one branch (usually `main`), with a directory per
  environment (`overlays/dev`, `overlays/staging`, `overlays/prod`). Promotion is a
  change to the target environment's folder. Every environment is visible in one
  tree, diffs are explicit, and history is linear.

**Folder wins** for auditability and clarity, and it's the near-universal convention.
A single `main` branch holds the truth for all environments; a reviewer sees exactly
which environment a PR touches and exactly what changes.

```text
config-repo/                      ← ONE branch (main) is the source of truth
└── apps/web/
    ├── base/                     ← shared manifests (the common case)
    └── overlays/
        ├── dev/      ← replicas: 1, image: :1.27.1 (candidate)   auto-sync
        ├── staging/  ← replicas: 2, image: :1.27.0               auto-sync
        └── prod/     ← replicas: 3, image: :1.27.0               manual gate
```

With Kustomize (Phase 6), `base/` holds what's common and each `overlay/` holds only
the differences — replica count, image tag, resource limits. A **promotion is just a
change to an overlay** — usually bumping the image tag that was validated one
environment earlier.

### Promotion by pull request

GitOps turns "deploy to staging" into "open a PR that changes `overlays/staging`."
The flow:

```text
  CI builds image :1.27.1, validates in dev
        │
        ▼
  PR: bump overlays/staging image tag  :1.27.0 → :1.27.1
        │  review (a human approves the diff)
        ▼
  merge to main  ──►  Argo CD sees overlays/staging changed  ──►  auto-sync staging
        │  staging validated
        ▼
  PR: bump overlays/prod  :1.27.0 → :1.27.1  ──►  merge  ──►  prod sync (gated)
```

Every promotion is a reviewed, attributable commit. "What's in prod?" is answered by
reading `overlays/prod` at `main`; "how did it get there?" is answered by `git log`.
CI can even **open the promotion PR automatically** after tests pass — promotion
becomes a reviewable diff a human approves, not a credentialed deploy.

### Sync waves: ordering a sync

A single sync often contains resources with **dependencies**: the namespace must
exist before the Deployment; a CRD must be established before its custom resources; a
database migration Job should run before the new Pods start. Argo CD orders a sync
with **sync waves** — an annotation on each resource:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"   # lower numbers apply first
```

Within a sync, Argo CD applies all resources in wave `-1`, waits for them to be
healthy, then wave `0`, then `1`, and so on (default wave is `0`). Typical ordering:
namespace (`-1`) → config/secrets (`0`) → workloads (`1`) → Services/Ingress (`2`).
PreSync/PostSync **hooks** (e.g. a migration Job) layer on top for lifecycle steps.
Waves make a multi-resource sync deterministic instead of a race.

### Rollback by revert

Because Git is the source of truth, **rollback is `git revert`**. You revert the
commit that introduced the bad change; Argo CD sees the environment is now OutOfSync
against the restored state and reconciles back. No special tooling, no snapshot — the
same mechanism as forward delivery, run backward. Across environments, Git history
*is* the correlation: the commit that promoted a change to prod points at the diff to
revert, and reverting it returns prod to the exact prior declared state.

---

## 2. Why it matters for platform engineering

Multi-environment promotion is the day-to-day workflow a delivery platform exists to
provide:

- **It's the paved road for shipping.** Teams promote by opening a PR against a
  folder — no environment-specific credentials, no bespoke deploy scripts. The same
  motion works for every service.
- **Environments stay consistent and auditable.** A folder layout makes "what differs
  between staging and prod" a one-line diff, which is how you catch the config drift
  that causes "works in staging, breaks in prod."
- **Production gets the right guardrails.** You configure fast auto-sync for dev and
  staging but a manual gate (and sync windows) for prod — centrally, once, for every
  team.
- **Recovery is routine.** Rollback is a revert any engineer can do and any reviewer
  can understand, which shortens incidents.
- **It composes with 08.3.** An ApplicationSet with a list/git generator produces the
  per-environment Applications from this folder layout, so the whole promotion
  pipeline is itself declarative.

---

## 3. Mental model

Environments are **folders**, promotion is a **diff you move forward**, and a sync is
an **ordered** reconcile. The loop is the same as always — Git is desired state —
only now there are several destinations, each reading its own folder.

```text
   main branch (one source of truth)
   ├── overlays/dev     ──► Application web-dev     ──► reconcile ──► namespace web-dev
   ├── overlays/staging ──► Application web-staging ──► reconcile ──► namespace web-staging
   └── overlays/prod    ──► Application web-prod     ──► reconcile ──► namespace web-prod
                                   ▲
     promotion = a PR that copies a validated change from one overlay to the next
     rollback  = git revert of that PR; the loop reconciles back
```

Three rules to remember:

1. **Folders, not branches.** One branch of truth; a directory per environment.
2. **Promote a diff, don't redeploy.** Move the validated change forward by PR; don't
   rebuild per environment.
3. **Order with waves; recover with revert.** Sync waves sequence a rollout; `git
   revert` reverses it.

---

## 4. Minimal implementation

The smallest honest multi-environment setup is a Kustomize base plus two overlays
that differ only by what must differ. The "promotion" is visible as a one-field diff:

```bash
# Render each environment and compare — the diff IS the promotion surface.
kubectl kustomize overlays/dev      | grep -E 'image:|replicas:'
# → image: nginx:1.27.1-alpine   replicas: 1    (candidate under test in dev)
kubectl kustomize overlays/prod     | grep -E 'image:|replicas:'
# → image: nginx:1.27.0-alpine   replicas: 3    (current prod)
```

```yaml
# overlays/prod/kustomization.yaml — prod differs from base ONLY where it must.
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: web-prod
resources:
  - ../../base
  - namespace.yaml          # annotated sync-wave "-1": created before the workload
patches:
  - path: replicas-patch.yaml   # replicas: 3
images:
  - name: nginx
    newTag: 1.27.0-alpine        # promoting = bump this to the validated tag
```

Promoting `1.27.1-alpine` to prod is a one-line change to `newTag`, reviewed as a PR;
rolling back is `git revert` of that commit. The lab turns this into the full
dev→staging→prod workflow with sync waves and a manual prod gate.

---

## 5. Hands-on lab

You'll build a base-plus-overlays config repo for dev, staging, and prod; render each
overlay to see the promotion surface; watch Argo CD apply a sync in wave order
(namespace → config → workload → service); promote a validated image tag forward by a
PR-style commit; gate prod behind a manual sync; and roll an environment back with
`git revert`.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Environment parity.** Overlays should differ *only* where they must (scale,
  tags, limits, hostnames). The more base you share, the less "works in staging,
  fails in prod." Review overlay diffs for accidental divergence.
- **Promotion automation and provenance.** Have CI open the promotion PR with the
  exact validated digest (prefer immutable image **digests** over mutable tags), so
  what you tested is byte-for-byte what you ship.
- **Production gates.** Use manual sync and **sync windows** to require approval and
  to block deploys during freezes or outside business hours — while keeping dev and
  staging fully automated.
- **Sync-wave health gating.** Waves advance only when the prior wave is healthy;
  make sure your resources report health correctly (e.g. a migration Job must
  actually complete) or a sync can stall. Keep waves few and meaningful.
- **Rollback correlation.** Record which commit is live in each environment (Argo CD
  tracks the synced revision). During an incident you want to map "prod is broken" to
  "revert commit abc123" in seconds.
- **Config vs app repos.** Keep the config repo separate from app source so a
  promotion PR touches only deployment intent, with its own reviewers and branch
  protection.

---

## 7. Common mistakes

- **Branch-per-environment.** Branches diverge, promotion becomes merge archaeology,
  and "what's different in prod?" is unanswerable. *Fix:* one branch, a folder per
  environment.
- **Copy-pasting whole environments.** Duplicating full manifests per env guarantees
  drift and double edits. *Fix:* a shared base with thin overlays holding only
  differences.
- **Mutable image tags (`:latest`, floating tags).** "It worked yesterday" because
  the tag moved under you. *Fix:* pin immutable tags or digests and promote the exact
  artifact.
- **No ordering, racey syncs.** Workloads start before their namespace/config/CRDs
  exist and fail intermittently. *Fix:* sync waves (and PreSync hooks for migrations).
- **Auto-syncing prod like dev.** A bad merge ships straight to customers. *Fix:*
  manual sync gate and sync windows on prod; fast auto-sync below it.
- **Treating rollback as special.** Scrambling for a bespoke rollback path during an
  incident. *Fix:* rehearse `git revert`; it's just delivery in reverse.

---

## 8. Assessment

**Knowledge checks**

1. Give two concrete reasons folder-per-environment beats branch-per-environment.
2. In a Kustomize layout, what belongs in `base/` vs an `overlay/`?
3. What problem do sync waves solve, and which wave would a namespace use relative to
   its Deployment?
4. How do you roll back a bad production change in GitOps?
5. Why gate prod with a manual sync while leaving dev on auto-sync?

**Concept exercise**

> Describe how you'd promote a change from test to production **without using the
> words "merge a branch" or naming a tool.** Explain promotion as moving a reviewed
> difference forward, so it would apply to any declarative delivery system.

**Trade-off / debugging exercise**

> A team runs `dev`, `staging`, `prod` as three long-lived branches and keeps hitting
> "staging and prod have silently drifted." Propose a folder-based redesign and say
> what it fixes. Then: after a prod sync, the new Pods crash-loop because their
> namespace and config aren't present yet. Explain the ordering bug and the exact
> sync-wave annotations that fix it.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Environments are all visible on one branch (explicit diffs, linear
  history), and promotion is a reviewable config change rather than a divergent
  branch merge; no branch drift or cherry-pick tangle.
- **Q2:** `base/` holds what's common to all environments; an `overlay/` holds only
  the per-environment differences (replicas, image tag, limits, hostnames).
- **Q3:** They order a multi-resource sync by dependency. A namespace uses a *lower*
  wave (e.g. `-1`) than its Deployment (e.g. `1`) so it exists first.
- **Q4:** `git revert` the commit that introduced the change; the agent reconciles
  the environment back to the restored declared state.
- **Q5:** Dev values speed and fast feedback; prod values control and reviewability.
  A manual gate (plus sync windows) prevents an unreviewed or ill-timed change from
  reaching customers automatically.
- **Debugging:** the redesign is one `main` branch with `overlays/{dev,staging,prod}`
  so drift is a visible diff. The crash-loop is a wave ordering bug: annotate the
  Namespace `sync-wave: "-1"` and config `"0"` so they apply (and go healthy) before
  the Deployment at `"1"`.

</details>

---

## 9. Further reading

- Kustomize — [Bases and overlays](https://kubectl.docs.kubernetes.io/references/kustomize/)
- Argo CD — [Sync phases and waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
- Argo CD — [Sync windows](https://argo-cd.readthedocs.io/en/stable/user-guide/sync_windows/)
  and [resource hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/)
- Codefresh — [Environment promotion and the GitOps repo-per-environment debate](https://codefresh.io/blog/how-to-model-your-gitops-environments-and-promote-releases-between-them/)
- Argo CD — [Best practices: separate config and source repos](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [08.3 — Argo CD ApplicationSets](../03-argocd-applicationsets/)
· _Next:_ [08.5 — Secrets in GitOps →](../05-secrets-in-gitops/)
