<!-- markdownlint-disable MD033 -->
# Baseline report — <cluster name> — <date>

> Fill this in during the lab. Replace every `<placeholder>`. Rank by **blast
> radius** (what a breach could reach and do), not by the number of findings.

## 1. Cluster under test

- Cluster: `<kind cluster name>`
- Kubernetes version: `<kubectl version --short>`
- Assessed by: `<you>`
- Date: `<YYYY-MM-DD>`

## 2. kube-bench summary (CIS Benchmark)

| Section | PASS | FAIL | WARN | INFO |
|---------|------|------|------|------|
| Totals  | `<n>` | `<n>` | `<n>` | `<n>` |

### Top 5 findings (ranked)

| # | CIS control | Verdict | Defence-in-depth layer | Blast radius if unfixed | Remediation |
|---|-------------|---------|------------------------|-------------------------|-------------|
| 1 | `<id>` | `<FAIL/WARN>` | `<1–7>` | `<what an attacker gains>` | `<kube-bench's fix>` |
| 2 | `<id>` | | | | |
| 3 | `<id>` | | | | |
| 4 | `<id>` | | | | |
| 5 | `<id>` | | | | |

## 3. OWASP Kubernetes Top 10 self-assessment

Exposure: `yes` (clearly exposed), `partial` (some mitigation), or `no` (mitigated).
Priority: `1` = highest blast radius, `3` = lowest.

| ID | Risk | Exposed? | Evidence | Priority | Fixed in module |
|----|------|----------|----------|----------|-----------------|
| K01 | Insecure workload configurations | `<y/p/n>` | `<evidence>` | `<1–3>` | 13.3, 13.5 |
| K02 | Supply chain vulnerabilities | | | | 13.5, 13.6 |
| K03 | Overly permissive RBAC | | | | 13.2 |
| K04 | Lack of centralized policy enforcement | | | | 13.3 |
| K05 | Inadequate logging & monitoring | | | | 13.7 |
| K06 | Broken authentication | | | | 13.1, 13.2 |
| K07 | Missing network segmentation controls | | | | 13.6, 13.8 |
| K08 | Secrets management failures | | | | 13.4 |
| K09 | Misconfigured cluster components | | | | 13.1 |
| K10 | Outdated & vulnerable components | | | | 13.5 |

## 4. Backlog — top 3 to fix first

1. `<highest blast-radius item>` — why: `<one line>`
2. `<second>` — why: `<one line>`
3. `<third>` — why: `<one line>`

## 5. Notes

- `<anything surprising: a green score hiding a design flaw, a WARN that's actually
  critical, a layer with no owner, etc.>`
