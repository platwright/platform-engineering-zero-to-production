# Build Guide — GitOps Platform

> The staged walkthrough. **Pass 1** stands up the whole platform on a free local
> `kind` cluster with ArgoCD and your own Git config repo, then has you promote a
> change, watch self-healing, and roll back. **Pass 2** hardens it to production as
> later phases teach each piece. Pass 1 takes ~1.5–2 hours.

**Type:** Build project
**Deliverable:** A reproducible, multi-team, multi-environment GitOps platform where
ArgoCD reconciles the cluster from Git, dev/staging auto-sync, prod is a manual gate,
and promotion happens by pull request.

## Prerequisites

- Docker, `kubectl`, `kind`, `git`, and the
  [`argocd` CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/).
- A **Git host** for your config repo (a free GitHub repo is ideal).
- You're in this project directory:
  `09-platform-project-02/gitops-platform/`.

---

## Pass 1 — Build it now (local, free)

### Stage 0 — Create your config repo

GitOps needs a Git URL ArgoCD can reach. Copy this project's `config-repo/` contents
into a new repo on your Git host and wire in its URL:

```bash
# Create an empty repo on your Git host first, then:
export CONFIG_REPO_URL="https://github.com/<you>/gitops-config.git"

# Work from a copy of the config-repo contents
cp -r config-repo /tmp/gitops-config && cd /tmp/gitops-config
git init -b main

# Replace the placeholder with your repo URL everywhere
grep -rl __CONFIG_REPO_URL__ . | xargs sed -i "s|__CONFIG_REPO_URL__|$CONFIG_REPO_URL|g"

git add -A && git commit -m "init gitops config"
git remote add origin "$CONFIG_REPO_URL" && git push -u origin main
cd -   # back to the project directory
```

> On macOS, `sed -i` needs an argument: use `sed -i ''  "s|...|...|g"` or install GNU
> sed. On Windows, do this inside WSL2.

### Stage 1 — Bootstrap the cluster and ArgoCD

```bash
export CONFIG_REPO_URL="https://github.com/<you>/gitops-config.git"
./scripts/bootstrap.sh
```

This creates a kind cluster, installs ArgoCD, and applies the **app-of-apps** root
Application pointed at your repo. One apply bootstraps everything.

### Stage 2 — Watch the platform converge

```bash
# All Applications ArgoCD now manages:
kubectl -n argocd get applications

# Expect: root, platform, team-a-service-1-dev, team-a-service-1-staging,
#         team-a-service-1-prod, team-b-service-2-dev/staging/prod
```

Open the UI to see the sync/health graph (optional but worth it):

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo          # the admin password
kubectl -n argocd port-forward svc/argocd-server 8080:443   # https://localhost:8080 (user: admin)
```

Confirm the workloads landed and that **dev/staging are Synced** while **prod is
OutOfSync** (the manual gate):

```bash
kubectl get pods -n team-a-dev
kubectl get pods -n team-a-staging
kubectl -n argocd get application team-a-service-1-prod   # SYNC STATUS: OutOfSync
```

### Stage 3 — Sync production through the manual gate

Production never auto-applies. Review the diff, then sync deliberately:

```bash
# Log in the CLI (same admin password as above)
argocd login localhost:8080 --username admin --password <password> --insecure

argocd app diff team-a-service-1-prod      # review what WOULD change
argocd app sync team-a-service-1-prod      # the human decision to ship
kubectl get pods -n team-a-prod            # 3 replicas now running
```

That OutOfSync-until-synced behavior is the production safety gate. dev and staging
got there on their own; prod waited for you.

### Stage 4 — Promote a change by pull request

Make a change the GitOps way — edit Git, let ArgoCD reconcile. Bump team-a's dev
replica count:

```bash
cd /tmp/gitops-config
# change count: 1 -> 2 in the dev overlay
sed -i 's/count: 1/count: 2/' apps/team-a/service-1/overlays/dev/kustomization.yaml
git commit -am "team-a/service-1: scale dev to 2"
git push
cd -
```

Within a minute ArgoCD detects the commit and reconciles dev automatically:

```bash
kubectl -n argocd get application team-a-service-1-dev -w   # watch it sync
kubectl get pods -n team-a-dev                              # now 2 replicas
```

> In a real team this edit is a **pull request** reviewed before merge. In Pass 2,
> CI opens that PR automatically with the new image digest.

### Stage 5 — Watch GitOps self-heal

Delete a live resource and watch ArgoCD put it back (dev/staging have `selfHeal`):

```bash
kubectl -n team-a-dev delete deployment service-1
kubectl -n argocd get application team-a-service-1-dev -w
# ArgoCD detects drift from Git and recreates the Deployment
kubectl get deploy -n team-a-dev
```

The cluster converges to Git, not the other way around. Manual `kubectl` changes are
transient; Git wins.

### Stage 6 — Roll back by reverting a commit

The Git history *is* your deployment history. Undo Stage 4:

```bash
cd /tmp/gitops-config
git revert --no-edit HEAD        # revert the "scale dev to 2" commit
git push
cd -
kubectl get pods -n team-a-dev   # back to 1 replica after ArgoCD syncs
```

No `kubectl rollout undo`, no snowflake state — just revert and let ArgoCD converge.

### Stage 7 — Clean up

```bash
./scripts/cleanup.sh             # deletes the kind cluster
rm -rf /tmp/gitops-config        # optional: remove the local clone
# delete the repo on your Git host if you no longer need it
```

---

## Pass 2 — Harden to production (as later phases teach it)

Return to each item after the relevant phase. The
[`config-repo/platform/pass2/`](./config-repo/platform/pass2/) folder holds starting
manifests.

1. **Secrets via ESO + GCP Secret Manager** — install ESO, wire a `SecretStore`, and
   point an Application at `platform/pass2/eso-example.yaml`. Nothing secret in Git.
   → [Phase 10 · Security](../../13-security-and-policy-engineering/)
2. **Signed-image policy** — install Kyverno and enable
   `platform/pass2/kyverno-verify-images.yaml` so only signed `ghcr.io/org` images
   run.
   → [Phase 10 · Security](../../13-security-and-policy-engineering/)
3. **CI-driven promotion** — have the application repo's CI build→scan→sign→push,
   then open a PR that writes the new image **digest** into the overlay.
   → [Phase 5 · CI/CD](../../06-cicd-for-platform-teams/)
4. **Notifications** — ArgoCD Notifications to Slack/email on sync and drift.
   → [Phase 9 · Observability](../../11-observability-engineering/)

As you finish each, update the
[portfolio-ready checklist](./README.md#portfolio-ready-checklist).

---

## Reflection

- You changed the cluster three ways in this guide: a promotion (Stage 4), a deletion
  (Stage 5), and a rollback (Stage 6). In every case the cluster ended up matching
  Git. Why is "the cluster converges to Git" such a powerful operational property?
- Production required a manual sync while dev/staging didn't. Where else would you add
  friction deliberately, and where would you remove it?
- The config repo is now your production control plane. What protections does it need
  (branch protection, CODEOWNERS, signed commits) that a normal app repo might not?
