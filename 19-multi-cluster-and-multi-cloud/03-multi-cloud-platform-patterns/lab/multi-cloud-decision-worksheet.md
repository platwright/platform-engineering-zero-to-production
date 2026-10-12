<!-- markdownlint-disable MD033 -->

# Multi-cloud decision worksheet

Fill in every `<placeholder>`. This one page is your defensible answer to "should we be
multi-cloud?" — a driver, a cost estimate, and a position on the dial. Keep it with your
architecture decision records; it is the reasoning the next engineer will thank you for.

## 0. Scenario

Pick one (or substitute your own real org):

- **A — SaaS startup.** Profitable, entirely on one cloud, heavy use of that cloud's managed
  Postgres and queue. A new CTO wants "multi-cloud to avoid lock-in."
- **B — Regulated fintech.** A regulator requires certain customer data to live in a
  specific sovereign cloud; the rest of the product runs elsewhere.
- **C — Post-acquisition.** You acquired a company running on a second cloud; both products
  must keep shipping.

| Field | Your answer |
|-------|-------------|
| Scenario chosen | `<A / B / C / my own: ...>` |
| One-line description | `<...>` |

## 1. Name the driver

| Question | Your answer |
|----------|-------------|
| The multi-cloud driver, in ONE sentence | `<...>` |
| Does it name an external constraint (regulation / acquisition / unique service / provider-DR)? | `<yes / no>` |
| Driver classification | `<real / weak>` |
| If weak: what is the real underlying need? | `<e.g. reduce switching cost, satisfy a customer, survive a region outage>` |

## 2. What kind of multi-cloud is actually being asked for?

| Option | Does it fit this scenario? Why / why not |
|--------|------------------------------------------|
| Incidental / polycloud (separate single-cloud workloads) | `<...>` |
| Portability-ready (one cloud now, low switching cost) | `<...>` |
| Actively multi-cloud (one workload spanning clouds) | `<...>` |

## 3. Abstraction leak audit (from the XRD + Compositions)

List concrete things that do **not** map cleanly between the two clouds' object storage.
Classify each as *hidden* (lowest-common-denominator — a capability you cannot offer) or
*exposed* (a cloud-specific field that breaks portability).

| # | Mismatch between S3 and GCS | Hidden or exposed? | Consequence |
|---|------------------------------|--------------------|-------------|
| 1 | `<e.g. bucket naming / global uniqueness rules>` | `<hidden / exposed>` | `<...>` |
| 2 | `<e.g. per-object ACL vs bucket IAM>` | `<hidden / exposed>` | `<...>` |
| 3 | `<e.g. storage-class names / lifecycle rules>` | `<hidden / exposed>` | `<...>` |
| 4 (optional) | `<...>` | `<hidden / exposed>` | `<...>` |

## 4. Cost premium estimate

Order-of-magnitude is fine — enough to weigh against the driver's value.

| Cost driver | Rough estimate | Notes |
|-------------|----------------|-------|
| Duplicated expertise (people / training) | `<$ per month or FTE>` | `<...>` |
| Duplicated tooling and automation | `<effort / $>` | `<...>` |
| Inter-cloud networking (VPN / Interconnect) | `<$ per month>` | `<...>` |
| Monthly cross-cloud data egress | `<$ per month>` | `<GB moved × per-GB rate>` |
| Lowest-common-denominator tax | `<what you give up + rebuild cost>` | `<e.g. can't use best managed DB>` |
| **Total premium vs single-cloud** | `<$ per month / %>` | `<...>` |

## 5. Data gravity check

| Question | Your answer |
|----------|-------------|
| Where does the primary dataset live, and how big is it? | `<cloud + size>` |
| What would it cost and take to move it to another cloud? | `<$ + time>` |
| Does data cross a cloud boundary on the hot path? | `<yes / no — where?>` |
| Can compute be co-located with its data per cloud? | `<yes / no>` |

## 6. Decision

| Field | Your answer |
|-------|-------------|
| Position on the dial | `<single-cloud / portability-ready / actively-multi-cloud>` |
| One-line recommendation | `<...>` |
| Top justification #1 | `<...>` |
| Top justification #2 | `<...>` |
| If portability-ready: the 3 cheapest exit-readiness steps | `<e.g. standardize on K8s, isolate managed-service coupling behind an interface, keep IaC + open formats>` |
| The condition that WOULD change this to actively multi-cloud | `<the named driver that would appear>` |

## 7. One-paragraph defense

Write the paragraph you would say to the CTO who wants multi-cloud "to avoid lock-in":

> `<Your defense: what you asked, the cost drivers you surfaced, the portability-ready plan
> you proposed, and the explicit condition under which you would agree to go further.>`
