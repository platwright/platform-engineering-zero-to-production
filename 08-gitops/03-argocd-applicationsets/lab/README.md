# Lab — Generate Applications with ApplicationSets and app-of-apps

> You'll stop hand-writing Applications. First a **list generator** produces one
> Application per environment; then a **git directory generator** produces one per
> app folder in the public example repo; finally an **app-of-apps** root creates
> several Applications from a single entry point. You'll scale out by changing
> *data*, not manifests.

**Estimated time:** ~50–65 minutes
**Type:** Build
**Deliverable:** Three working generation patterns on one cluster — a list-based
ApplicationSet, a git-directory ApplicationSet, and an app-of-apps root — each
producing healthy child Applications.

## Objectives

- Generate Applications from a list generator and scale it by editing the list.
- Generate one Application per directory with a git generator (onboard by folder).
- Bootstrap multiple Applications from a single app-of-apps root.
- Read generated Applications and understand deletion semantics.

## Prerequisites

- A kind cluster with **Argo CD installed** (repeat Steps 1 of the
  [Module 08.2 lab](../../02-argocd-fundamentals/lab/README.md) if you deleted it).
  The ApplicationSet controller ships with Argo CD — nothing extra to install.
- Starter manifests in this folder: [`applicationset-list.yaml`](./applicationset-list.yaml),
  [`applicationset-git.yaml`](./applicationset-git.yaml),
  [`app-of-apps.yaml`](./app-of-apps.yaml), and the example children in
  [`apps/`](./apps/).

## Steps

1. **Ensure Argo CD is running.**

   ```bash
   kind create cluster --name pe-appsets        # skip if 08.2's cluster still exists
   kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
   kubectl apply -n argocd \
     -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   kubectl -n argocd rollout status deploy/argocd-applicationset-controller --timeout=180s
   ```

2. **Apply the list-generator ApplicationSet.** One list, two Applications:

   ```bash
   kubectl apply -f applicationset-list.yaml
   kubectl -n argocd get applicationset
   kubectl -n argocd get applications      # -> guestbook-dev and guestbook-prod
   ```

   The single ApplicationSet rendered two Applications from its template.

3. **Scale by editing data, not manifests.** Add a third environment to the list and
   re-apply — a new Application appears with no new manifest:

   ```bash
   # Append "- env: staging" to the list in applicationset-list.yaml, then:
   kubectl apply -f applicationset-list.yaml
   kubectl -n argocd get applications      # -> a guestbook-staging Application joins
   ```

4. **Apply the git-directory-generator ApplicationSet.** One Application per matching
   folder in the public repo:

   ```bash
   kubectl apply -f applicationset-git.yaml
   kubectl -n argocd get applications \
     -l argocd.argoproj.io/application-set-name=guestbook-variants
   # -> guestbook, helm-guestbook, kustomize-guestbook (jsonnet variants excluded)
   ```

   Each child used `{{path}}` for its source and `{{path.basename}}` for its name and
   namespace. Adding a folder to the repo would add an Application automatically —
   that's self-service onboarding.

5. **Observe deletion semantics (carefully).** Removing a generator result removes
   its Application. Delete the ApplicationSet and watch its children go:

   ```bash
   kubectl delete -f applicationset-git.yaml
   kubectl -n argocd get applications      # the three variants are removed
   ```

   In production this is exactly why you gate deletion (`preserveResourcesOnDeletion`)
   so an accidental folder removal can't wipe live resources.

6. **Bootstrap with app-of-apps.** Apply one root Application that renders and syncs
   several children:

   ```bash
   kubectl apply -f app-of-apps.yaml
   kubectl -n argocd get applications
   # -> app-of-apps, plus example.guestbook and example.kustomize-guestbook
   ```

   Syncing the single root created the children, which deployed the workloads. Open
   [`apps/guestbook.yaml`](./apps/guestbook.yaml) to see what a child looks like as a
   plain manifest — in your own repo, the root's `path` points at a folder of files
   like these.

7. **Confirm the workloads are healthy.**

   ```bash
   kubectl get pods -n guestbook
   kubectl get pods -n kustomize-guestbook
   kubectl -n argocd get applications      # every app Synced + Healthy
   ```

## Expected result

One list ApplicationSet (scaled from two to three envs by editing a list), one git
ApplicationSet that produced an Application per folder, and one app-of-apps root that
bootstrapped multiple children — all **Synced + Healthy**. You scaled GitOps without
writing a single additional Application by hand.

## Cleanup

> Tear everything down so nothing lingers. Never skip this.

```bash
kubectl delete -f app-of-apps.yaml --ignore-not-found
kubectl delete -f applicationset-list.yaml --ignore-not-found
kubectl delete -f applicationset-git.yaml --ignore-not-found
# If you only want to reset apps but keep Argo CD, stop here. Otherwise:
kind delete cluster --name pe-appsets
```

## Reflection

- You added an environment by appending one line to a list. How does that change the
  cost of onboarding the 50th app versus the first?
- Deleting the git ApplicationSet removed its children. What single setting would
  protect live resources from an accidental folder deletion, and why is it off by
  default?
- The app-of-apps root is itself an Application. How would you manage *it* via GitOps
  so even the bootstrap entry point is declared in a repo?

## Stretch goals (optional)

- Convert the list generator to a **matrix** of `env × a second list` (e.g. region)
  and preview how many Applications it would generate before applying.
- Switch an ApplicationSet to `goTemplate: true` and use a conditional in the
  template (e.g. enable `prune` only for non-prod) to feel why Go templating beats
  string substitution.
- Push the `apps/` child manifests to your own Git repo and point a real app-of-apps
  root at that folder — the fully self-hosted version of Step 6.
