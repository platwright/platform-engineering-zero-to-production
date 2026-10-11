# Lab — Enrich the Portal with Plugins

> Add the ArgoCD, Kubernetes, Grafana, and cost plugins to your Backstage app, bind
> them to a catalog entity with annotations, and view the enriched entity page. Then
> scaffold a custom plugin. The install/config/annotation work is local; live data
> needs optional backends.

**Estimated time:** ~50–75 minutes
**Type:** Build
**Deliverable:** A service entity page showing (at least configured, ideally live)
ArgoCD, Kubernetes, Grafana, and cost cards — plus a scaffolded custom plugin.

## Objectives

- Install and configure four plugins via config snippets.
- Wire plugins to an entity using `catalog-info.yaml` annotations.
- Scaffold a custom plugin skeleton and understand its two halves.

## Prerequisites

- [Module 15.5](../README.md) and a running Backstage app
  ([Module 15.2](../../02-backstage-fundamentals/)).
- The entity annotations from [Module 15.3](../../03-backstage-software-catalog/)
  (`argocd/app-name`, `backstage.io/kubernetes-id`).
- The starter file [`app-config.plugins.yaml`](./app-config.plugins.yaml).
- **Optional (live data):** an ArgoCD instance, a Kubernetes cluster + read-only
  service-account token, and a Grafana instance. All free to run locally (kind +
  ArgoCD + Grafana), but not required to complete the lab.

## Steps

1. **Install the plugin packages** (from the Backstage app root):

   ```bash
   yarn --cwd packages/app add @backstage/plugin-kubernetes @roadiehq/backstage-plugin-argo-cd @roadiehq/backstage-plugin-grafana @backstage/plugin-cost-insights
   yarn --cwd packages/backend add @backstage/plugin-kubernetes-backend
   ```

2. **Apply the config.** Merge the blocks from
   [`app-config.plugins.yaml`](./app-config.plugins.yaml) into your `app-config.yaml`
   (kubernetes clusters, the ArgoCD/Grafana proxy, and cost). Secrets come from
   environment variables — never commit tokens.

3. **Annotate the entity.** Ensure your `checkout-service` `catalog-info.yaml` carries
   the binding annotations:

   ```yaml
   metadata:
     annotations:
       argocd/app-name: checkout-service
       backstage.io/kubernetes-id: checkout-service
       grafana/dashboard-selector: "tags @> 'checkout-service'"
   ```

4. **Add the cards to the entity page.** In
   `packages/app/src/components/catalog/EntityPage.tsx`, add the ArgoCD, Kubernetes,
   Grafana, and cost components to the layout (each plugin's README shows the exact
   import and `EntitySwitch` snippet). Restart `yarn dev`.

5. **View the enriched page.** Open `checkout-service`. With backends configured you
   see live sync status, pods/events, an embedded dashboard, and cost; without them you
   see the cards render with a clear "not configured" state — proving the wiring.

6. **Scaffold a custom plugin.** Create a custom frontend plugin skeleton and note its
   structure:

   ```bash
   yarn backstage-cli new --select plugin
   # name it e.g. "oncall"; inspect plugins/oncall/src for the React entity card
   ```

   Sketch (in comments) how its backend would read an on-call schedule from PagerDuty
   and render it on the team (`Group`) entity page.

## Expected result

The `checkout-service` entity page shows ArgoCD, Kubernetes, Grafana, and cost cards
(live if you configured backends, "not configured" otherwise), and a custom `oncall`
plugin skeleton exists under `plugins/`. The entity page is now a single pane of glass.

## Cleanup

> Revert local config and remove any throwaway cluster/ArgoCD/Grafana you spun up.

```bash
# Stop `yarn dev` (Ctrl-C). Remove plugin cards/config you added if this was a throwaway
# app. If you created a local kind cluster for live data:
kind delete cluster
# Delete any local ArgoCD/Grafana installs. No managed cloud resources are required.
```

## Reflection

- Which single plugin would most change a developer's daily workflow, and why?
- Every empty card traces back to a missing annotation — where should that annotation
  come from so it is never missing? (Module 15.4's skeleton.)
- Which plugin surfaces each of Projects 1, 2, and 3?

## Stretch goals (optional)

- Run a local kind cluster and ArgoCD, and get the Kubernetes and ArgoCD cards showing
  real data.
- Flesh out the custom `oncall` plugin to render static sample data on the Group page.
- Add the cost plugin's backend data source using OpenCost against a local cluster.
