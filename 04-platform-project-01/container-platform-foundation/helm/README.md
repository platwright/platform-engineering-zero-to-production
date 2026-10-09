# Helm — Pass 2 (package the golden-path workload)

> 🚧 **Pass 2.** The hardened sample in
> [`../kubernetes/apps/team-a-hello.yaml`](../kubernetes/apps/team-a-hello.yaml) is
> raw YAML. In Pass 2 you'll package the golden-path workload as a reusable,
> parameterized **Helm chart** so every team deploys the same hardened defaults by
> setting a few values. You build this in
> **[Phase 6 · Kubernetes Package Management](../../../07-kubernetes-package-management/)**.

## Target

A `platform-app` chart (see also [`shared/helm-charts/`](../../../shared/helm-charts/))
that ships, by default:

- a non-root, read-only, capability-dropped Deployment,
- a Service, HPA, PodDisruptionBudget, ServiceAccount, and NetworkPolicy,
- a `values.schema.json` so bad values are rejected early, and
- `helm test` smoke tests.

Teams then deploy with something like:

```bash
helm upgrade --install hello oci://ghcr.io/your-org/charts/platform-app \
  --version 1.0.0 -n team-a -f team-a-values.yaml
```

The point: encode the hardened golden path **once**, let every team consume it.
