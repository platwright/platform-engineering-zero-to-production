<!-- markdownlint-disable MD033 -->
# Right-sizing worksheet

> Compare actual usage to requests and recommend new requests at roughly
> **p95 usage + headroom**. Replace every `<...>` placeholder. In production, source
> the usage from 30 days of Prometheus data (or VPA recommendations), including peaks;
> in the lab a single `kubectl top` reading is enough to see the gap.

## Per-container analysis

| Workload / container | CPU requested | CPU used (p95) | Mem requested | Mem used (p95) | Verdict |
|----------------------|---------------|----------------|---------------|----------------|---------|
| `<overshoot>` | `500m` | `<e.g. 2m>` | `512Mi` | `<e.g. 3Mi>` | `<over / right / under>` |
| `<svc-b>` | `<n>` | `<n>` | `<n>` | `<n>` | `<...>` |
| `<svc-c>` | `<n>` | `<n>` | `<n>` | `<n>` | `<...>` |

## Recommendation

For each over- or under-provisioned container, recommend new requests at
`p95 + headroom` (a common headroom is 20–30%).

| Container | New CPU request | New Mem request | CPU reclaimed | Mem reclaimed |
|-----------|-----------------|-----------------|---------------|---------------|
| `<overshoot>` | `<e.g. 10m>` | `<e.g. 16Mi>` | `<e.g. 490m>` | `<e.g. 496Mi>` |
| `<svc-b>` | `<n>` | `<n>` | `<n>` | `<n>` |

- **Total CPU reclaimed across the sample:** `<n>`
- **Total memory reclaimed across the sample:** `<n>`

## Scale-out impact

> The real argument for right-sizing is leverage across the whole platform.

- Services on the platform: `<N>`
- Average reclaim per service (from your sample): `<cpu>`, `<mem>`
- Projected cluster capacity reclaimed: `<N × average>` → fewer nodes Karpenter must
  provision.

## Cautions

- Size on **peaks (p95+)**, not averages — under-sizing causes OOM kills and throttling.
- Ship recommendations to teams (or use VPA in recommend mode); do not silently change
  their requests.
- Do not run HPA and VPA on the **same** metric for the same workload — they fight.
