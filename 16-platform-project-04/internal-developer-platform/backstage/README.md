# Backstage — the IDP's developer control plane

> This directory holds the Backstage configuration that turns a vanilla Backstage app
> into **this platform's** IDP: the software catalog, the golden-path templates, and
> the integrations that wire in Projects 1–3. You scaffold a Backstage app with
> `npx @backstage/create-app` (Module 15.2) and layer these in.

## Files

| File | Role | Plane |
|------|------|-------|
| [`app-config.idp.yaml`](./app-config.idp.yaml) | Catalog locations, GitHub integration + auth, TechDocs, and org discovery (Pass 2) | control |
| [`catalog/org.yaml`](./catalog/org.yaml) | The org catalog: Domain, Systems, Groups (teams), and platform Components | control |

## How this maps to the five planes

The IDP is the **developer control plane** that ties the other four planes together
([Module 01.4](../../../01-platform-foundations/04-the-internal-developer-platform/README.md)):

```text
   Backstage (this config)        ← developer control plane
     ├─ software catalog          who owns what, where it runs
     ├─ golden-path templates     self-service "create a service"
     └─ plugins (Pass 2):
          ArgoCD plugin           → integration & delivery plane (Project 2)
          Kubernetes plugin       → resource plane (Project 1)
          Grafana plugin          → monitoring plane (Project 3)
          Cost Insights plugin    → monitoring plane (Phase 14)
```

## Using it

1. Scaffold a Backstage app (Module 15.2): `npx @backstage/create-app --path idp-app`.
2. Merge [`app-config.idp.yaml`](./app-config.idp.yaml) into the app's
   `app-config.yaml` (adjust the relative `target:` paths to where you place the
   catalog and templates).
3. Set `GITHUB_TOKEN`, `AUTH_GITHUB_CLIENT_ID`, `AUTH_GITHUB_CLIENT_SECRET` in the
   environment (Pass 2) — never commit them.
4. `yarn dev`, open `http://localhost:3000`, and confirm the catalog and the two
   golden-path templates appear.

Full walkthrough: [../build-guide.md](../build-guide.md).

> **Plugins (Pass 2).** The ArgoCD, Kubernetes, Grafana, and Cost Insights plugins are
> installed into the Backstage app's packages and configured per
> [Module 15.5](../../../15-developer-experience-and-idp/05-backstage-plugins/). They
> need the live Project 2/3 stack to show data, so they're a Pass-2 step.
