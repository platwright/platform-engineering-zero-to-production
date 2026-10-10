# Lab — Multi-environment promotion with overlays and sync waves

> You'll build a base-plus-overlays config repo for dev, staging, and prod; prove the
> overlays differ only where they must; watch Argo CD apply a sync in **wave order**;
> then promote a validated image tag forward by a PR-style commit and roll it back
> with `git revert`. Core steps run with zero accounts; the full promotion loop uses a
> free Git repo of your own.

**Estimated time:** ~55–70 minutes
**Type:** Build
**Deliverable:** A dev/staging/prod overlay layout with sync waves, a demonstrated
promotion (tag moved forward by commit), and a demonstrated rollback (by revert).

## Objectives

- Render and compare per-environment overlays to see the promotion surface.
- Observe sync-wave ordering during an Argo CD sync.
- Promote a change dev → staging → prod by committing overlay edits.
- Gate production behind a manual sync and roll back with `git revert`.

## Prerequisites

- A kind cluster with **Argo CD installed** (see the [Module 08.2 lab](../../02-argocd-fundamentals/lab/README.md)).
- `kubectl` (its built-in `kustomize`) and `git`. The `argocd` CLI is handy.
- Starter config repo in this folder: [`config-repo/`](./config-repo/) (base, three
  overlays, and three Argo CD Applications) plus
  [`application-sync-waves.yaml`](./application-sync-waves.yaml).
- For the full promotion loop (Steps 4–7): a **free** Git repo you control
  (GitHub/GitLab/Gitea). Steps 1–3 need no account.

## Steps

1. **Ensure Argo CD is running.**

   ```bash
   kind create cluster --name pe-multienv       # skip if a prior cluster exists
   kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
   kubectl apply -n argocd \
     -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   kubectl -n argocd rollout status deploy/argocd-server --timeout=180s
   ```

2. **Render the overlays and compare (no account needed).** See that each environment
   differs only where it must:

   ```bash
   cd config-repo
   for env in dev staging prod; do
     echo "== $env =="
     kubectl kustomize apps/web/overlays/$env | grep -E 'kind: Namespace|image:|replicas:'
   done
   ```

   You should see `web-dev` (1 replica, tag `1.27.1-alpine` — the candidate),
   `web-staging` (2 replicas, `1.27.0-alpine`), and `web-prod` (3 replicas,
   `1.27.0-alpine`). The promotion surface is the image tag.

3. **Watch sync waves order a real sync (no account needed).** Apply the public
   sync-waves example and sync it; Argo CD applies resources wave by wave, not all at
   once:

   ```bash
   kubectl apply -f ../application-sync-waves.yaml
   argocd app sync sync-waves        # watch the PreSync hook, then waves 1, 2, 3
   argocd app get sync-waves         # resources show their wave order
   ```

   This is the mechanism your overlays rely on: namespace (`-1`) → config (`0`) →
   Deployment (`1`) → Service (`2`).

4. **Publish the config repo and wire the Applications (free Git repo).** Push
   `config-repo` to a repo you control, then stamp its URL into the three
   Applications and apply them:

   ```bash
   # From inside ./config-repo — create a repo on your Git host first, then:
   git init -b main
   git add . && git commit -m "initial dev/staging/prod config"
   git remote add origin "$GITOPS_REPO"      # e.g. https://github.com/<you>/pe-gitops-config.git
   git push -u origin main

   for app in argocd/web-*.yaml; do
     sed "s|https://github.com/your-org/pe-gitops-config.git|$GITOPS_REPO|" "$app" \
       | kubectl apply -f -
   done
   kubectl -n argocd get applications
   ```

5. **Observe auto-sync below, a manual gate on prod.** Dev and staging reconcile
   automatically; prod stays **OutOfSync** until you approve it:

   ```bash
   kubectl get deploy -n web-dev -n web-staging --ignore-not-found
   argocd app get web-prod               # OutOfSync — waiting at the manual gate
   argocd app sync web-prod              # deliberately deploy prod (wave-ordered)
   kubectl get deploy -n web-prod
   ```

6. **Promote a validated tag forward (PR-style commit).** Dev runs `1.27.1-alpine`;
   promote it to staging, then prod, by editing each overlay and committing — exactly
   what a promotion PR does:

   ```bash
   # Promote to staging:
   sed -i 's/newTag: 1.27.0-alpine/newTag: 1.27.1-alpine/' apps/web/overlays/staging/kustomization.yaml
   git commit -am "promote web 1.27.1-alpine to staging"
   git push                              # Argo CD auto-syncs staging to the new tag

   # After staging looks good, promote to prod and approve the gated sync:
   sed -i 's/newTag: 1.27.0-alpine/newTag: 1.27.1-alpine/' apps/web/overlays/prod/kustomization.yaml
   git commit -am "promote web 1.27.1-alpine to prod"
   git push
   argocd app sync web-prod
   kubectl -n web-prod get pods -o jsonpath='{.items[*].spec.containers[*].image}'; echo
   ```

7. **Roll back prod by reverting the commit.** Rollback is delivery in reverse — no
   special tooling:

   ```bash
   git revert --no-edit HEAD             # undo the prod promotion commit
   git push
   argocd app sync web-prod              # prod reconciles back to 1.27.0-alpine
   argocd app history web-prod           # the revision history shows both states
   ```

   > No free Git repo? You can still practice the mechanics locally: edit an overlay,
   > `kubectl kustomize apps/web/overlays/staging | grep image:` to preview the
   > promotion diff, then `git revert` in a local repo to see the rollback — the same
   > commits, without the cluster round-trip.

## Expected result

Three environments driven from one branch, each reading its own overlay; a sync that
applied resources in wave order; a tag promoted dev → staging → prod by reviewable
commits with prod gated behind a manual sync; and a one-command rollback by revert.
That is the full multi-environment GitOps workflow.

## Cleanup

> Tear everything down so nothing lingers. Never skip this.

```bash
kubectl delete -f ../application-sync-waves.yaml --ignore-not-found
kubectl -n argocd delete application web-dev web-staging web-prod --ignore-not-found
kubectl delete namespace web-dev web-staging web-prod sync-waves-demo --ignore-not-found
kind delete cluster --name pe-multienv
```

## Reflection

- Promotion was a one-line tag change in a reviewed commit. How does that compare, for
  auditability, with running a deploy script against each environment?
- Prod required a manual sync while dev and staging did not. Where else would you add
  gates (sync windows, approvals), and what would you keep fast?
- You rolled back with `git revert`. Why is "rollback is just delivery in reverse"
  safer than keeping a separate rollback tool or restoring from snapshots?

## Stretch goals (optional)

- Promote by **immutable digest** (`newName`/`digest`) instead of a tag, so the thing
  you ship is byte-for-byte what you validated.
- Replace the three hand-written Applications with an **ApplicationSet** (Module 08.3)
  using a list generator over `dev/staging/prod`, so the per-env Applications are
  generated from the folder layout.
- Add a **PreSync** migration Job (wave `-2`) to an overlay and watch it run and
  complete before the Deployment in a later wave starts.
