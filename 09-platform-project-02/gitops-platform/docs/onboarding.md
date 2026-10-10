# Onboarding a new service onto the GitOps platform

> This runbook adds a new team service to the GitOps platform. Because the platform
> uses **ApplicationSets with a Git directory generator**, onboarding is mostly
> "add a folder" — ArgoCD generates the Applications automatically. In Pass 1 it's a
> short manual procedure; the platform-engineering goal is to make it a **template**
> (a Backstage software template or a CLI command) so teams self-serve.

## Outcome

A new service (say `team-a/service-3`) gets:

- a `base/` (hardened Deployment + Service) and `overlays/dev,staging,prod`,
- Applications generated automatically by the existing ApplicationSets,
- dev/staging auto-syncing and prod behind the manual gate — with no new ArgoCD
  `Application` YAML to hand-write.

## Procedure

1. **Copy an existing service as a starting point** (in your config repo):

   ```bash
   cd /path/to/your/gitops-config
   cp -r apps/team-a/service-1 apps/team-a/service-3
   ```

2. **Rename the workload.** In `apps/team-a/service-3/base/`, change the
   Deployment/Service `name` and `app` labels from `service-1` to `service-3`, and
   update the `replicas`/`images` target name in each overlay's `kustomization.yaml`
   (the `name:` under `replicas:` must match the Deployment name).

3. **Confirm the namespaces exist.** The overlays deploy into `team-a-{dev,staging,
   prod}`, which already exist (from `platform/namespaces.yaml`). A brand-new *team*
   would also need its namespaces added there first.

4. **Render locally before you push** (catch mistakes early):

   ```bash
   kubectl kustomize apps/team-a/service-3/overlays/dev
   ```

5. **Commit and push.**

   ```bash
   git add apps/team-a/service-3
   git commit -m "team-a: onboard service-3"
   git push
   ```

6. **Watch ArgoCD generate the Applications.** The ApplicationSets pick up the new
   `overlays/*` folders and create `team-a-service-3-dev/staging/prod`:

   ```bash
   kubectl -n argocd get applications | grep service-3
   ```

   dev and staging auto-sync; prod waits for a manual sync.

## Definition of done

- [ ] `apps/<team>/<service>/base` + `overlays/{dev,staging,prod}` exist and render.
- [ ] Workload names/labels are updated consistently (no leftover `service-1`).
- [ ] ArgoCD shows the three generated Applications.
- [ ] dev/staging synced; prod OutOfSync (manual gate) as expected.

## Make it self-service (later)

Copying folders by hand is Pass 1. The platform move is to turn this into a
**golden-path template** so a developer creates a fully wired service (repo, CI,
GitOps overlays, dashboards) from one form or command — the subject of
[Phase 12 · Developer Experience & IDP](../../../15-developer-experience-and-idp/)
and [Capstone 2](../../../21-capstone-projects/).
