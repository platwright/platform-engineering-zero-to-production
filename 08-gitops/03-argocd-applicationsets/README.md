# Module 08.3 — Argo CD ApplicationSets

> One `Application` per service, per environment, per cluster does not scale — you'd
> hand-write and maintain hundreds of near-identical manifests. **ApplicationSets**
> generate Applications from a template and a *generator*, so onboarding a new app,
> environment, or cluster becomes "add a directory" or "add a list entry." This
> module covers generators, templating, and the related **app-of-apps** pattern.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 08.2 — Argo CD Fundamentals](../02-argocd-fundamentals/) with Argo CD installable on a local kind cluster.

## Learning objectives

By the end of this module you will be able to:

- Explain what an **ApplicationSet** is and how its controller generates
  Applications.
- Choose the right **generator** — list, git (directory/file), cluster, matrix,
  merge — for a problem.
- Template Applications with generator parameters and avoid common templating traps.
- Contrast the **app-of-apps** pattern with ApplicationSets and know when to use
  each.
- Design app/environment onboarding so it's a one-line or one-folder change.

---

## 1. Concept

### The scaling problem

In Module 08.2 you wrote one `Application`. Now imagine 40 services across dev,
staging, and prod on three clusters. Hand-writing `40 × 3 × 3 = 360` Applications —
and keeping them consistent as policy changes — is exactly the copy-paste toil a
platform is supposed to delete. You want to declare the *pattern* once and let
something stamp out the instances.

### ApplicationSet: a template plus a generator

An **ApplicationSet** is a controller (bundled with Argo CD) and a custom resource
that produces Applications from two parts:

- A **generator** that yields a set of parameter maps (one per thing you want an
  Application for).
- A **template** — an `Application` spec with `{{placeholders}}` filled from each
  generator's parameters.

The controller renders `template × generator results` into real Applications and
keeps them reconciled: add an entry to the generator and a new Application appears;
remove it and the Application (optionally) goes away.

```text
   generator (produces a set)        template (one Application, parameterized)
   ─────────────────────────         ────────────────────────────────────────
     { env: dev,  cluster: a }                 name: web-{{env}}
     { env: stg,  cluster: a }   ──►  render   path: overlays/{{env}}
     { env: prod, cluster: b }                 namespace: web-{{env}}
                 │
                 ▼
     Application web-dev, Application web-stg, Application web-prod  (kept in sync)
```

### The generators you'll actually use

- **List generator** — an explicit, hand-written list of parameter maps. Best for a
  small, stable set like your environments. Simple and predictable.
- **Git generator (directory)** — one Application per *directory* matching a glob in
  a repo (e.g. `apps/*`). Onboard an app by adding a folder. This is the workhorse
  for monorepo-of-apps layouts.
- **Git generator (file)** — one Application per *config file* (e.g. each
  `config.json` under `apps/`), with the file's contents available as parameters.
  Best when each app needs structured, per-app values.
- **Cluster generator** — one Application per cluster registered in Argo CD. Best for
  rolling a platform add-on (ingress, cert-manager) out to every cluster.
- **Matrix generator** — the Cartesian product of two generators, e.g.
  *(git directory: each app) × (list: each cluster)*. Powerful; also the easiest to
  make explode, so use it deliberately.
- **Merge generator** — combine generators by a key to override/augment parameters
  (e.g. base values from one generator, per-cluster overrides from another).

### The app-of-apps pattern

Before (and alongside) ApplicationSets there's a simpler composition pattern: a
single **root Application** whose Git `path` contains *other `Application`
manifests*. Syncing the root creates all the child Applications, which in turn
deploy workloads. It's how you **bootstrap** a cluster from one entry point: point
Argo CD at the root, and the whole platform unfolds.

```text
   root Application  ──deploys──►  child Application manifests (in Git)
         (the "app of apps")             │  each is itself reconciled
                                         ▼
                              workloads: ingress, monitoring, the apps…
```

**app-of-apps vs ApplicationSet:** app-of-apps is a *static* tree — you write each
child Application by hand (or generate them). ApplicationSet is *dynamic* — children
are generated from data (directories, a list, clusters). A common real design uses
**an app-of-apps root that contains a few ApplicationSets**: one entry point, and
most children generated. Use app-of-apps for bootstrapping/composition; reach for
ApplicationSets when the children are repetitive and data-driven.

### Templating notes

Parameters are substituted with `{{param}}`. The git directory generator exposes
`{{path}}` (full path), `{{path.basename}}` (last segment — handy for names and
namespaces), and path segments. Newer Argo CD supports **Go templating**
(`goTemplate: true`) for conditionals and functions, which is far more robust than
string substitution for anything non-trivial. Keep names DNS-safe and deterministic
so generated Applications are stable across renders.

---

## 2. Why it matters for platform engineering

ApplicationSets are how GitOps becomes a *platform capability* rather than a
per-app chore:

- **Onboarding is self-service.** With a git directory generator, a team ships a new
  service by adding a folder and opening a PR — no platform ticket, no hand-written
  Application. That's the paved road.
- **Consistency by construction.** Every generated Application inherits the same
  template: the same project, sync policy, labels, and guardrails. Policy changes in
  one place, not 360.
- **Fleet operations.** The cluster generator rolls a platform add-on to every
  cluster at once; the matrix generator deploys every app to every environment from
  one resource.
- **Bootstrapping.** app-of-apps (often containing ApplicationSets) lets you rebuild
  an entire cluster's platform layer from a single root Application — core to
  disaster recovery and to standing up new clusters in Project 2 and beyond.

---

## 3. Mental model

An ApplicationSet is a **factory** sitting in front of the reconcile loop: the
generator decides *how many* Applications exist and *with what parameters*, the
template decides *what each one is*, and the Argo CD controller then reconciles each
generated Application exactly as in Module 08.2.

```text
   data source ──► [ GENERATOR ] ──► set of params ──► [ TEMPLATE ] ──► N Applications
   (list/git/                                                              │
    clusters)                                                              ▼
                                                        each reconciled Git → cluster
```

Three rules to remember:

1. **Generator = how many and with what; template = what each is.** Keep the two
   concerns separate in your head.
2. **Change the data, not the manifests.** Add a directory/list entry to scale out;
   don't hand-edit generated Applications.
3. **app-of-apps composes; ApplicationSet generates.** Bootstrap with the former,
   scale repetition with the latter.

---

## 4. Minimal implementation

The smallest ApplicationSet uses a **list generator** to produce two Applications
from one template — the "hello world" of generation:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: guestbook-envs
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - env: dev
          - env: prod
  template:
    metadata:
      name: 'guestbook-{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps
        targetRevision: HEAD
        path: guestbook
      destination:
        server: https://kubernetes.default.svc
        namespace: 'guestbook-{{env}}'
      syncPolicy:
        automated: { prune: true, selfHeal: true }
        syncOptions: [ CreateNamespace=true ]
```

```bash
kubectl apply -f applicationset-list.yaml
kubectl -n argocd get applicationset,applications
# → one ApplicationSet produced two Applications: guestbook-dev and guestbook-prod
```

Add `- env: staging` to the list and a third Application appears on the next
reconcile. You changed *data*, not manifests — that's the whole idea. The lab scales
this up with a git directory generator and an app-of-apps.

---

## 5. Hands-on lab

You'll build a list-generator ApplicationSet (one Application per environment), then
a git-directory-generator ApplicationSet that creates one Application per app folder
in the public example repo, and finally an app-of-apps root that composes multiple
Applications from a single entry point.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Deletion behavior.** By default, removing a generator result deletes its
  Application (and, with prune, its workloads). Set
  `preserveResourcesOnDeletion` or use the ApplicationSet's deletion policies when
  that's too aggressive — a mistaken file deletion shouldn't wipe prod.
- **Matrix blast radius.** A matrix of *(apps) × (clusters)* can generate thousands
  of Applications from a tiny change. Review renders (there's a dry-run/preview) and
  constrain generators so an edit can't carpet-bomb the fleet.
- **Progressive syncs.** ApplicationSets can roll changes out in ordered waves across
  the generated Applications (e.g. dev before prod), so one template change doesn't
  hit every environment simultaneously.
- **Go templating over string substitution.** For anything with conditionals,
  defaults, or nested values, enable `goTemplate: true` — naive `{{...}}` substitution
  silently produces broken manifests.
- **Generator source security.** The git generator reads structure/values from a
  repo; who can add a directory or edit a config file can now create Applications.
  Scope write access and pair it with `AppProject` restrictions.
- **Stable, DNS-safe names.** Generated names must be deterministic and valid;
  non-deterministic names cause churn (delete/recreate) on every reconcile.

---

## 7. Common mistakes

- **Hand-maintaining many near-identical Applications.** The exact toil
  ApplicationSets exist to remove. *Fix:* identify the varying dimension (env, app,
  cluster) and express it as a generator.
- **Reaching for a matrix generator first.** It's the most powerful and the easiest
  to make explode. *Fix:* start with list or git-directory; add matrix only when you
  truly need the product, and preview the render.
- **String templating complex values.** `{{...}}` substitution can't do conditionals
  and will emit invalid YAML silently. *Fix:* enable `goTemplate: true`.
- **Forgetting deletion semantics.** Deleting a folder/list entry can delete live
  resources. *Fix:* understand and configure deletion/preserve policies before you
  rely on it in prod.
- **Confusing app-of-apps with ApplicationSet.** Writing dozens of child Applications
  by hand "because app-of-apps," when a generator would produce them. *Fix:* use
  app-of-apps to compose/bootstrap, ApplicationSets to generate repetition — often
  together.
- **Unbounded git generators over an untrusted repo.** Anyone who can add a directory
  can create an Application. *Fix:* restrict repo write access and bound
  destinations with an `AppProject`.

---

## 8. Assessment

**Knowledge checks**

1. What two parts make up an ApplicationSet, and what does each decide?
2. Which generator onboards a new app by "just adding a folder," and what does
   `{{path.basename}}` give you?
3. When would you choose a cluster generator over a list generator?
4. What's the difference between app-of-apps and an ApplicationSet?
5. Why is the matrix generator the one to use most cautiously?

**Concept exercise**

> Explain how you'd deploy 30 microservices to 3 environments **without writing 90
> Application manifests** — and do it without naming any specific generator. Describe
> the "template plus a set of parameters" idea so it would apply to any GitOps tool.

**Trade-off / debugging exercise**

> A teammate proposes a single matrix generator of *(every app) × (every cluster) ×
> (every environment)* to manage the whole company from one resource. Give two
> concrete risks and a safer decomposition. Then: after someone deletes an `apps/`
> subfolder in a PR, a production service disappears. Explain the mechanism and two
> ways to prevent a folder deletion from deleting live prod resources.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** A **generator** (produces the set of parameter maps — how many and with
  what) and a **template** (the parameterized `Application` — what each one is).
- **Q2:** The **git directory generator**; `{{path.basename}}` is the final path
  segment (the folder name), handy for the Application name and namespace.
- **Q3:** When you want one Application *per cluster* (e.g. rolling a platform add-on
  to every registered cluster) rather than an explicit hand-listed set.
- **Q4:** app-of-apps is a *static* composition — a root Application whose path holds
  hand-written child Applications; ApplicationSet *dynamically generates* children
  from data. They're often combined.
- **Q5:** It's a Cartesian product — a small change multiplies into many
  Applications, so it has the largest blast radius.
- **Debugging:** the git generator created one Application per folder; deleting the
  folder removed the generator result, which deleted the Application and (with prune)
  its resources. Prevent it with `preserveResourcesOnDeletion`/deletion policies,
  branch protection + review on the config repo, and treating prod folders as
  protected paths.

</details>

---

## 9. Further reading

- Argo CD — [ApplicationSet overview](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
- Argo CD — [Generators](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators/)
  (list, git, cluster, matrix, merge)
- Argo CD — [The app-of-apps pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- Argo CD — [ApplicationSet Go templating](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/GoTemplate/)
- Argo CD — [Progressive syncs](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Progressive-Syncs/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [08.2 — Argo CD Fundamentals](../02-argocd-fundamentals/)
· _Next:_ [08.4 — Multi-Environment GitOps →](../04-multi-environment-gitops/)
