# config-repo — observability platform config

> The declarative config for the observability stack. In Pass 1 the
> [bootstrap script](../scripts/bootstrap.sh) applies these with Helm; in Pass 2 you
> put this directory under ArgoCD (from [Project 2](../../../09-platform-project-02/))
> so the whole stack is delivered by GitOps.

## Layout

```text
config-repo/
├── platform/
│   ├── otel-collector/     # agent (DaemonSet) + gateway (Deployment) configs + Helm values
│   ├── prometheus/         # kube-prometheus-stack values + a sample PrometheusRule
│   ├── loki/               # Loki Helm values (single-binary, filesystem)
│   ├── tempo/              # Tempo Helm values (single-binary, filesystem)
│   ├── grafana/            # datasources + dashboard provider (as code)
│   └── alertmanager/       # routing → Slack (Pass 2)
└── slos/                   # Sloth SLO definitions (generate burn-rate rules)
```

## What each piece does

| Path | Role |
|------|------|
| [`otel-collector/agent-config.yaml`](./platform/otel-collector/agent-config.yaml) | Per-node agent: host metrics + pod logs → gateway |
| [`otel-collector/gateway-config.yaml`](./platform/otel-collector/gateway-config.yaml) | Gateway: batch, **tail-sample traces**, fan out to backends |
| [`otel-collector/otel-values.yaml`](./platform/otel-collector/otel-values.yaml) | Helm values (install once per mode) |
| [`prometheus/prometheus-values.yaml`](./platform/prometheus/prometheus-values.yaml) | kube-prometheus-stack (Prometheus + Grafana + Alertmanager) |
| [`prometheus/sample-alert-rule.yaml`](./platform/prometheus/sample-alert-rule.yaml) | A simple error-rate alert to see firing |
| [`loki/loki-values.yaml`](./platform/loki/loki-values.yaml) | Loki (logs) |
| [`tempo/tempo-values.yaml`](./platform/tempo/tempo-values.yaml) | Tempo (traces) |
| [`grafana/datasources.yaml`](./platform/grafana/datasources.yaml) | Prometheus + Loki + Tempo datasources, with correlation |
| [`grafana/dashboard-provider.yaml`](./platform/grafana/dashboard-provider.yaml) | Loads dashboards-as-code from a directory |
| [`alertmanager/alertmanager-routing.yaml`](./platform/alertmanager/alertmanager-routing.yaml) | Pass 2: route pages/tickets to Slack |
| [`slos/argocd-slo.yaml`](./slos/argocd-slo.yaml) | Sloth SLO for ArgoCD sync availability |

> **Sizing note:** every values file here is laptop-sized (single replica, short
> retention, filesystem storage). Production uses object storage (GCS), longer
> retention, and HA — see [../architecture/architecture.md](../architecture/architecture.md).
