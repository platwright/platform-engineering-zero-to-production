# Cheat Sheet — Helm & Kustomize

> Helm templates and versions releases from charts; Kustomize patches plain YAML
> with overlays and no templating language. Many teams use both together.

## Helm concepts

- **Chart** - a package of templated Kubernetes manifests plus `values.yaml`.
- **Release** - an installed instance of a chart in a cluster/namespace.
- **Values** - parameters that fill templates; override per environment.
- **Repository** - an index of charts over HTTP, or an **OCI** registry.

## Helm repos and search

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo nginx
helm search hub wordpress
```

## Helm install, upgrade, rollback

```bash
helm install web ./chart -n app --create-namespace
helm install web bitnami/nginx -f values.yaml --set replicaCount=3
helm upgrade --install web ./chart -n app -f values-prod.yaml --atomic
helm history web -n app
helm rollback web 1 -n app
helm uninstall web -n app
helm list -A
```

- `--atomic` rolls back automatically if the upgrade fails; `--install` makes
  `upgrade` create the release if absent (idempotent in CI).

## Helm inspect and test

```bash
helm template web ./chart -f values.yaml      # render locally, no cluster
helm lint ./chart
helm get values web -n app
helm get manifest web -n app
helm test web -n app                          # run chart test hooks
helm diff upgrade web ./chart -f values.yaml  # needs the helm-diff plugin
```

## Helm OCI registries

```bash
helm package ./chart                          # produces web-0.1.0.tgz
helm push web-0.1.0.tgz oci://ghcr.io/org/charts
helm install web oci://ghcr.io/org/charts/web --version 0.1.0
```

## Chart structure & templating

```text
chart/
  Chart.yaml           # name, version, appVersion, dependencies
  values.yaml          # default values
  templates/           # *.yaml templates + _helpers.tpl
  charts/              # vendored subcharts
```

- Reference values as `{{ .Values.replicaCount }}`; define reusable snippets in
  `_helpers.tpl` and call them with `{{ include "chart.labels" . }}`.
- `--set key=val` overrides one value; `-f file.yaml` overrides many. Later `-f`
  files and `--set` flags win; use `helm template` to inspect the result.
- Pin dependency versions in `Chart.yaml`, then run `helm dependency update` to
  vendor subcharts into `charts/`.

## Kustomize concepts

- **Base** - a reusable set of manifests plus a `kustomization.yaml`.
- **Overlay** - an environment that references a base and patches it.
- **No templating** - you declare the base, then layer strategic-merge or JSON 6902
  patches, generators, and transformers on top.

## Kustomize kustomization.yaml

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
namespace: prod
namePrefix: prod-
commonLabels:
  env: prod
images:
  - name: ghcr.io/org/web
    newTag: v2.1.0
replicas:
  - name: web
    count: 5
patches:
  - path: patch-resources.yaml
    target:
      kind: Deployment
      name: web
configMapGenerator:
  - name: app-config
    literals:
      - LOG_LEVEL=info
```

## Kustomize build and apply

```bash
kubectl kustomize ./overlays/prod            # render to stdout
kubectl apply -k ./overlays/prod             # build + apply
kustomize build ./overlays/prod | kubectl apply -f -
```

## Helm vs Kustomize

| | Helm | Kustomize |
|--|------|-----------|
| Mechanism | Go templating + values | Overlays patch plain YAML |
| Packaging / versioning | Yes (charts, OCI) | No (just directories) |
| Best for | Distributable apps, parameters | Env variants of your own YAML |
| In kubectl | No (separate binary) | Yes (`kubectl -k`) |

## See also

- [`../07-kubernetes-package-management/`](../07-kubernetes-package-management/) -
  Helm, Kustomize, Helm vs Kustomize, and OCI distribution.
