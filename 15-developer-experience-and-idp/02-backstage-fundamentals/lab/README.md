# Lab — Scaffold and Run Backstage Locally

> Scaffold a Backstage app with the official generator, run it on `localhost`, explore
> the four core plugins, and wire up GitHub sign-in. Optional, clearly marked steps add
> a PostgreSQL backend and a GKE deployment. The core of this lab is **100% local and
> free**.

**Estimated time:** ~45–75 minutes (local core); +30–45 (optional cloud)
**Type:** Build
**Deliverable:** A Backstage app running at `http://localhost:3000`, with the catalog,
scaffolder, TechDocs, and search visible — and (optionally) GitHub sign-in working.

## Objectives

- Scaffold and run Backstage locally with `npx @backstage/create-app`.
- Navigate the four core plugins and the `app-config.yaml` that drives them.
- Configure GitHub authentication (optional) and understand the Node + Postgres shape.

## Prerequisites

- [Module 15.2](../README.md).
- **Node.js 20 or newer** and **Yarn** (`node --version` should print `v20` or higher).
- Git and a free GitHub account.
- **Scaffold outside this course repo** (e.g. in `~/backstage-lab`) so you never commit
  `node_modules`.
- Optional cloud steps need a GKE cluster, `kubectl`, and Helm — see the cost note.

## Steps

1. **Scaffold the app** (run in a scratch directory, not the course repo):

   ```bash
   cd ~            # or any folder OUTSIDE this repo
   npx @backstage/create-app@latest
   # Enter an app name when prompted, e.g. "idp-portal"
   cd idp-portal
   ```

   This generates a monorepo with `app-config.yaml`, `packages/app` (frontend), and
   `packages/backend` (backend) — every core feature already wired as a plugin.

2. **Install and run:**

   ```bash
   yarn install
   yarn dev
   ```

   Open `http://localhost:3000`. The backend runs on `:7007`. You are signed in as
   **guest** using a local SQLite database (development only).

3. **Explore the four core plugins.** In the UI, visit each and note what it shows:

   - **Catalog** (home) — the seeded example component.
   - **Create** (scaffolder) — the sample "create" template.
   - **Docs** (TechDocs) — the example documentation.
   - **Search** — try searching for the example component.

4. **Read the config that drives it.** Open `app-config.yaml` and find the
   `app`, `backend`, `auth`, and `catalog` sections. Locate where the example catalog
   entities are registered (`catalog.locations`). This file is the control surface for
   the rest of the phase.

5. **(Optional) Add GitHub sign-in.** Create a GitHub OAuth App
   (Settings → Developer settings → OAuth Apps) with callback
   `http://localhost:7007/api/auth/github/handler/frame`. Then export the credentials
   and add the provider:

   ```bash
   export AUTH_GITHUB_CLIENT_ID=<your-client-id>
   export AUTH_GITHUB_CLIENT_SECRET=<your-client-secret>
   ```

   ```yaml
   # app-config.yaml — add under the existing `auth:` key
   auth:
     environment: development
     providers:
       github:
         development:
           clientId: ${AUTH_GITHUB_CLIENT_ID}
           clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}
   ```

   Restart `yarn dev` and sign in with GitHub. Credentials come from environment
   variables — never commit them.

6. **(Optional, cloud — has cost) Point at PostgreSQL and deploy to GKE.** Configure
   the Postgres backend and deploy with the community Helm chart using the provided
   values file:

   ```yaml
   # app-config.production.yaml — use Postgres instead of SQLite
   backend:
     database:
       client: pg
       connection:
         host: ${POSTGRES_HOST}
         port: ${POSTGRES_PORT}
         user: ${POSTGRES_USER}
         password: ${POSTGRES_PASSWORD}
   ```

   ```bash
   helm repo add backstage https://backstage.github.io/charts
   helm upgrade --install backstage backstage/backstage \
     -f backstage-values.yaml -n platform-system --create-namespace
   ```

   See [`backstage-values.yaml`](./backstage-values.yaml) for a minimal, commented
   starting point.

## Expected result

Backstage running at `http://localhost:3000` showing the Catalog, Create, Docs, and
Search plugins. If you did the optional step, you sign in with GitHub instead of
guest. If you did the cloud step, `kubectl get pods -n platform-system` shows the
`backstage` pod running.

## Cleanup

> Stop local processes and tear down any cloud resources to avoid cost.

```bash
# Local: stop the dev server with Ctrl-C. Optionally remove the scaffolded app:
#   rm -rf ~/idp-portal
# This frees the large node_modules directory.

# Optional cloud teardown (only if you did Step 6):
helm uninstall backstage -n platform-system
kubectl delete namespace platform-system
# If you created a dedicated cluster/Cloud SQL for this lab, delete them too.
```

## Reflection

- How much of what you see is "the platform" versus just a *view* of it? (Recall "the
  portal is not the platform.")
- Which core plugin will you lean on most in the next three modules, and why?
- What would break if you deployed this exact local setup for your whole org?

## Stretch goals (optional)

- Replace the guest sign-in resolver so your GitHub identity maps to a catalog `User`.
- Pin the Backstage version and run `yarn backstage-cli versions:bump` to practice the
  upgrade flow.
- Add your own name and team to `examples/org.yaml` and see them appear in the catalog.
