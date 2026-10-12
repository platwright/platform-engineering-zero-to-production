# Module 19.4 — Global Load Balancing and Edge

> You have a fleet of clusters across regions (Modules 19.1–19.2). Now you put one front
> door on them so a user in Frankfurt and a user in São Paulo each hit a fast, nearby,
> *healthy* region — and so losing a whole region is a routing event, not an outage. The
> trap is to think this is a routing problem. Routing is the easy half. The hard half, the
> one that decides your whole design, is **state**: whether your data can be written in two
> regions at once. Choose active-active vs active-passive by your data, not your traffic.

**Estimated effort:** ~2–2.5 hours (theory + design exercise)
**You'll need:** [Module 19.1 · Multi-Cluster Architecture](../01-multi-cluster-architecture/) and the SLO/reliability thinking from [Phase 13 · Platform SRE](../../17-platform-sre/). No cloud accounts — this is a design lab.

## Learning objectives

By the end of this module you will be able to:

- Distinguish **active-active** from **active-passive** and tie each to **RTO/RPO** and cost.
- Explain how a global load balancer routes: **latency/geo routing**, **health-based
  failover**, and **anycast** vs **DNS**.
- Identify **state replication** as the real constraint, not traffic routing.
- Decide where **edge compute** earns its place and where it is a distraction.
- Design a global routing and failover topology for a given scenario.

---

## 1. Concept

### The goal, and the substrate

You want two things at once: every user served from a **nearby** region (low latency), and
the product **surviving the loss of a whole region** (availability). Your multi-region
clusters are the substrate; a **global load balancer** is the front door that sends each
request to the right region and stops sending to a dead one. Simple to say — and the
routing part really is simple. The design is dominated by what sits *underneath*: your data.

### Active-active vs active-passive (the decision that drives everything)

- **Active-active.** Every region serves traffic simultaneously. Best latency (everyone
  near a live region), best utilization (no idle hardware), and failover is nearly
  instant — you just stop routing to the failed region. The price is the hard part:
  **writes can land in any region**, so your data layer must handle multi-region writes
  (multi-primary with conflict resolution, or regional sharding so each record has a home
  region). Get this wrong and you get split-brain and lost writes.
- **Active-passive.** One region serves; a standby is promoted on failure. The data story
  is far simpler — one writer, asynchronous replica — so most teams start here. The costs
  are **idle standby capacity** and a non-zero **RTO** (time to detect, promote, and
  reroute) plus possible **RPO** loss (anything not yet replicated when the primary died).

```text
   ACTIVE-ACTIVE                              ACTIVE-PASSIVE
   ─────────────                              ──────────────
   users ─▶ global LB ─▶ region A (serving)   users ─▶ global LB ─▶ region A (serving)
                     └─▶ region B (serving)                     ·· region B (standby)
   failover: stop routing to the dead one     failover: promote B, then route to it
   RTO ≈ seconds, RPO ≈ 0*                    RTO = detect+promote, RPO = replication lag
   HARD PART: multi-region writes             HARD PART: tested, fast promotion
   *if the data layer truly supports it
```

The routing diagrams are almost identical; the **data layer** is where the real cost and
risk live. So the first question in any global design is not "which load balancer?" — it is
**"can my data be written in more than one region at once, and do I need it to?"**

### How a global load balancer routes

Two broad mechanisms put a user on a region:

- **DNS-based routing.** The load balancer is a smart DNS: it returns a different regional
  IP depending on the asker. **Latency routing** returns the lowest-latency healthy region;
  **geo routing** returns a region by the user's location (also used for data residency).
  Universal and simple — but **DNS caching (TTL)** means failover is only as fast as the
  TTL clients honour, which can be minutes.
- **Anycast routing.** The **same IP address** is announced from many points of presence;
  the internet's routing (BGP) delivers each user to the nearest PoP, and the provider's
  backbone carries them to a healthy region. **Anycast fails over in seconds** (no DNS TTL
  to wait out) and hides regional failure behind one stable IP. This is how GCP's global
  external load balancer, AWS Global Accelerator, and Cloudflare work.

Both are paired with **health-based failover**: each regional backend is health-checked, and
an unhealthy region is automatically removed from rotation. The quality of your health check
*is* the quality of your failover — a shallow check that only pings the load balancer will
happily route users into a region whose database is down.

### Anycast vs DNS, in one line

- **DNS/latency routing:** simple, works everywhere, failover limited by TTL. Fine for many
  apps.
- **Anycast:** one global IP, seconds-fast failover, needs a provider that offers it. Better
  for strict availability.

### Edge compute: thin, close, and cross-cutting

The **edge** is the CDN's PoPs — hundreds of locations close to users. **Edge compute**
(Cloudflare Workers, AWS Lambda@Edge, Fastly Compute) runs small, stateless logic there,
before a request ever reaches a region. It earns its place for **cross-cutting, latency-
sensitive, stateless** concerns:

- auth/token validation and bot filtering at the door,
- A/B routing, redirects, and header/geo rewrites,
- caching and request collapsing,
- serving static or personalized-but-cacheable content.

What the edge is **not**: a home for your core application or any stateful logic. State at
hundreds of PoPs is a consistency nightmare, and business logic scattered across the edge is
impossible to reason about. The platform rule is **keep the edge thin** — put cross-cutting
concerns that benefit *every* region there, version and observe them like any other
deployment, and keep the actual product in your regional clusters.

---

## 2. Why it matters for platform engineering

- **Availability is a platform SLO.** Surviving a regional outage is a capability the
  platform provides to every service on it (Phase 13). The global front door and a tested
  failover are how that SLO is met in practice.
- **Latency is product quality.** Routing users to a nearby region is often the single
  biggest latency win, and on many products latency moves revenue.
- **The routing layer makes a fleet one product.** Modules 19.1–19.2 built many clusters;
  the global LB is what makes them feel like one service to a user.
- **The data model is a platform-level decision.** Active-active vs active-passive determines
  your consistency, cost, and failure behaviour. Letting each team improvise it is how you
  get split-brain in one service and silent data loss in another.

## 3. Mental model

**Routing is the easy half; state is the hard half. Pick active-active vs active-passive by
your data, then let health checks and anycast (or DNS) handle the traffic.**

```text
                 users (worldwide)
                        │
            ┌───────────▼────────────┐   routes by: latency / geo / anycast
            │   GLOBAL LOAD BALANCER   │   removes unhealthy regions automatically
            └───┬──────────────┬──────┘
      health ✓  │              │  health ✗  (auto-removed from rotation)
                ▼              ▼
        ┌──────────────┐ ┌──────────────┐    EASY HALF ↑ (routing + health checks)
        │  region EU   │ │  region US   │    ─────────────────────────────────────
        │  cluster(s)  │ │  cluster(s)  │    HARD HALF ↓ (does your DATA allow this?)
        └──────┬───────┘ └──────┬───────┘
               └── data layer ──┘
          active-active: multi-region writes (sharded / multi-primary)  → RTO~0, RPO~0
          active-passive: one writer + async replica, promote on failure → RTO>0, RPO>0
```

Rules to keep: **choose the data model first** (it dictates everything above it); **your
failover is only as good as your health check and your last failover *test***; and **keep
the edge thin** — cross-cutting concerns only, never core state.

## 4. Minimal implementation

You cannot stand up a real global anycast LB for free, but the essence is tiny: a
**meaningful health endpoint** plus a **routing policy that drops unhealthy regions.** The
health check is the part you control and the part that matters most:

```text
# A DEEP health check actually exercises the dependencies failover depends on:
GET /healthz        → 200 only if THIS region can serve: app up AND its datastore reachable
                      (a shallow check that returns 200 from the LB proves nothing)
```

Everything else is policy you declare, not code you write — "route to the lowest-latency
healthy region, fail over when health drops":

```text
# Illustrative global routing policy (provider-agnostic shape):
record:  app.example.com
policy:  latency          # or: geo, weighted, failover
regions:
  - eu-west   backend: lb-eu   health: /healthz   priority: 1
  - us-east   backend: lb-us   health: /healthz   priority: 1   # active-active: equal priority
# active-passive instead: us-east priority 2 (only used when eu-west is unhealthy)
```

The whole lab is to design this deliberately — model, routing, health, failover, and the
data strategy underneath — for a concrete scenario, rather than discover the gaps during an
incident.

## 5. Hands-on lab

This is a **design lab**. For a global SaaS scenario you'll choose **active-active or
active-passive** (justified by the data, with RTO/RPO targets), design the **routing**
(latency/geo, anycast vs DNS), specify **health checks and automatic failover**, decide what
— if anything — belongs at the **edge**, and write a short **failover runbook** including a
game-day test. The deliverable is a completed global load-balancing design worksheet you
could hand to an on-call team.

➡️ **[Start the lab: Design a global front door](./lab/README.md)**

## 6. Production considerations

- **Decide the data strategy first.** Active-active needs a real multi-region write story
  (sharding by home region, or a multi-primary datastore with conflict handling);
  active-passive needs replication plus a **tested** promotion. This choice sets your RTO/RPO
  and most of your cost.
- **Test failover on a schedule.** An untested failover is a hope. Run game days that
  actually fail a region and measure real RTO/RPO; most "automatic" failovers break the first
  time they are used for real.
- **Make health checks deep and stable.** They must verify the region can truly serve (app
  plus critical dependencies), with thresholds that avoid flapping. Shallow checks cause
  false confidence; twitchy checks cause flapping failovers.
- **Mind failover speed vs DNS TTL.** If you rely on DNS routing, low TTLs speed failover but
  increase lookups; anycast sidesteps TTL entirely. Choose with your availability target in
  mind.
- **Handle TLS and identity globally.** Certificates, WAF rules, and auth must be consistent
  across regions and at the edge, or you get per-region drift and security gaps.
- **Account for statefulness and sessions.** Prefer stateless regional tiers; if you need
  session affinity, make it explicit and failover-safe rather than accidental.
- **Cost the model honestly.** Active-passive pays for idle standby; active-active pays for
  double-serving and cross-region data. Price both against the availability you actually need
  (Phase 14).
- **Keep the edge thin and observable.** Edge logic is still software — versioned, tested,
  monitored, and limited to cross-cutting concerns.

## 7. Common mistakes

- **Solving routing, ignoring data.** — The stateless web tier fails over cleanly while the
  database cannot, so "failover" serves errors or corrupts data. *Fix:* design the data layer
  first; match the routing model to it.
- **Active-active without a consistency plan.** — Serving writes in two regions with no
  multi-region write strategy, producing split-brain and lost updates. *Fix:* shard by home
  region or use a datastore built for multi-primary — or choose active-passive.
- **Never testing failover.** — A failover path that has only ever existed on a diagram.
  *Fix:* scheduled game days that fail a real region and measure RTO/RPO.
- **Long DNS TTLs.** — Failover "works" but clients keep hitting the dead region for minutes
  because of cached DNS. *Fix:* lower TTLs for failover-critical records, or use anycast.
- **Shallow health checks.** — Checks that pass while the app is broken, so traffic keeps
  flowing into a dead region. *Fix:* deep checks that exercise critical dependencies.
- **Business logic sprawled across the edge.** — Core, sometimes stateful, logic scattered
  over hundreds of PoPs, impossible to reason about. *Fix:* keep the edge thin; core logic
  and state stay in regional clusters.

## 8. Assessment

**Knowledge checks**

1. Contrast active-active and active-passive in terms of RTO, RPO, cost, and the hard part of
   each.
2. Why is state — not traffic routing — the real difficulty in going multi-region?
3. Explain anycast and how its failover behaviour differs from DNS-based routing.
4. What makes a health check "deep," and why does failover quality depend on it?
5. Give two good uses of edge compute and one thing that must **not** live at the edge.

**Concept exercise**

> Explain how a product keeps serving users worldwide with low latency and survives losing an
> entire region — **without using the words "load balancer," "anycast," or any product
> name.** Describe it in terms of where requests go, how a failed region is detected, and what
> happens to the data.

**Architecture / trade-off exercise**

> Design the global front door for a write-heavy SaaS with users in the EU and the US and a
> target of RTO < 1 minute, RPO ≈ 0. Decide active-active vs active-passive and **justify it
> from the data**, choose anycast or DNS routing, define the health check and automatic
> failover, and state what (if anything) you put at the edge. Then say how the design changes
> if the app is instead read-heavy and can tolerate RPO of a few minutes.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Active-active: RTO≈seconds, RPO≈0 (if the data layer truly supports multi-region
  writes), high utilization, hard part = multi-region writes/consistency. Active-passive:
  RTO = detect+promote, RPO = replication lag, pays for idle standby, hard part = fast,
  tested promotion.
- **Q2:** Routing a stateless request to another region is easy; keeping *data* correct and
  available across regions (writes, consistency, replication lag) is the genuine constraint,
  and it dictates whether active-active is even possible.
- **Q3:** Anycast announces one IP from many PoPs; the network routes each user to the
  nearest, and BGP reconverges in seconds on failure — unlike DNS routing, which is limited
  by clients caching records for the TTL.
- **Q4:** A deep check verifies the region can actually serve — app plus critical
  dependencies (e.g. its datastore) — so an unhealthy region is removed; a shallow check can
  pass while the app is broken, routing users into a dead region.
- **Q5:** Good: auth/bot filtering, A/B routing, redirects, header/geo rewrites, caching. Not
  at the edge: core application logic and any authoritative state.
- **Trade-off:** For write-heavy, RPO≈0, RTO<1 min: you need genuine multi-region writes —
  either shard by home region (EU users' data primary in EU, US in US) so each write has one
  authoritative region, or a multi-primary datastore with conflict handling; front it with
  anycast and deep health checks for seconds-fast failover. If instead read-heavy with
  RPO of minutes: active-passive is simpler and cheaper — one primary with async replicas,
  promote on failure; DNS latency routing with low TTLs may suffice, and you can serve reads
  from regional replicas. In both, edge stays thin (auth, caching).

</details>

## 9. Further reading

- Google Cloud — [External global Application Load Balancer overview](https://cloud.google.com/load-balancing/docs/https)
- AWS — [Global Accelerator (anycast) developer guide](https://docs.aws.amazon.com/global-accelerator/latest/dg/what-is-global-accelerator.html)
- AWS — [Route 53 routing policies (latency, geolocation, failover)](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy.html)
- Cloudflare — [How anycast works](https://www.cloudflare.com/learning/cdn/glossary/anycast-network/) and [Workers (edge compute)](https://developers.cloudflare.com/workers/)
- Google — [SRE Book: Load Balancing at the Frontend](https://sre.google/sre-book/load-balancing-frontend/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 19.3 — Multi-Cloud Platform Patterns](../03-multi-cloud-platform-patterns/) · _Next:_ [Phase 16 · Advanced Platform Topics →](../../20-advanced-platform-topics/)
