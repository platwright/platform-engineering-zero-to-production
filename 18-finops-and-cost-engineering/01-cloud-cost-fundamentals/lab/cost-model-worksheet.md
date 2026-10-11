<!-- markdownlint-disable MD033 -->

# Cost model worksheet

Fill in every `<placeholder>`. Compute each compute row as `count × rate × hours`
(use ~730 hours/month). Apply **−57%** (× 0.43) for a 3-year commitment and **−70%**
(× 0.30) for spot. Keep storage, egress, and managed services the same in both columns
for now.

## 1. Inventory and purchase choice

| Component | Spec / quantity | On-demand rate | Purchase option (optimized) | Why this option |
|-----------|-----------------|----------------|-----------------------------|-----------------|
| System node group | 2 × 4 vCPU/16 GB, 24/7 | \$0.19/hr | `<committed / on-demand / spot>` | `<reason>` |
| Web node group (floor) | ~2 × 8 vCPU/32 GB, 24/7 | \$0.38/hr | `<committed / on-demand / spot>` | `<reason>` |
| Web node group (spike) | ~1 × 8 vCPU/32 GB, daytime only | \$0.38/hr | `<committed / on-demand / spot>` | `<reason>` |
| Batch node group | ~3 × 8 vCPU/32 GB, interruptible | \$0.38/hr | `<committed / on-demand / spot>` | `<reason>` |
| Storage (SSD) | 800 GB-month | \$0.17/GB-mo | n/a | provisioned, not a purchase option |
| Egress (internet) | 1.5 TB/month | \$0.12/GB | n/a | architectural, see Module 18.4 |
| Managed services | control plane + small DB | flat | n/a | fixed for this model |

## 2. Monthly cost — two columns

| Line item | All on-demand (\$/mo) | Optimized blend (\$/mo) |
|-----------|-----------------------|-------------------------|
| System node group | `<...>` | `<...>` |
| Web node group (floor) | `<...>` | `<...>` |
| Web node group (spike) | `<...>` | `<...>` |
| Batch node group | `<...>` | `<...>` |
| Storage | `<...>` | `<...>` |
| Egress | `<...>` | `<...>` |
| Managed services | \$180.00 | \$180.00 |
| **Total** | `<BASELINE>` | `<OPTIMIZED>` |

## 3. Summary

```text
Baseline (all on-demand):   $<BASELINE>  / month
Optimized blend:            $<OPTIMIZED> / month
Absolute saving:            $<BASELINE - OPTIMIZED> / month
Percentage saved:           <(1 - OPTIMIZED/BASELINE) × 100> %
```

## 4. Notes and assumptions

- Biggest single saving came from: `<commit the floor / move batch to spot>`
- Commitment risk I am accepting: `<which capacity is locked for 1–3 years>`
- Spot interruption risk I am accepting: `<which workloads can be reclaimed>`
- The number I'd most want to replace with *measured* data: `<e.g. batch node average>`
