# 01 · Platform Foundations

> Before any Kubernetes, Terraform, or ArgoCD, you need to understand **what a
> platform is, who it's for, and why most platforms fail**. This phase is the
> conceptual bedrock the entire rest of the course builds on. Skipping it is how
> you end up building a technically impressive platform that nobody uses.

**Phase 1 · 5 modules · ~6–9 hours**

## Why start here?

It is tempting to jump straight to the tools. Resist it. The single most common
reason platform initiatives fail is **not** a technical mistake — it's building the
wrong thing: a platform designed around what the platform team found interesting
to build, rather than what developers actually needed.

This phase gives you the lenses you'll use for everything that follows:

- **Product thinking** — your platform has customers (developers). Treat it like a
  product, not an internal mandate.
- **Developer experience** — the thing you're actually optimizing, and how to
  measure it.
- **Architecture literacy** — a shared vocabulary (the IDP and its planes) for the
  systems you'll build in later phases.
- **Organizational design** — how a platform team is structured so it accelerates
  other teams instead of becoming a bottleneck.

Every later phase — containers, Kubernetes, IaC, GitOps, observability, security —
is in service of these ideas. Keep coming back to them.

## Modules

| # | Module | You'll learn | Lab deliverable |
|---|--------|--------------|-----------------|
| 1 | [What Is Platform Engineering?](./01-what-is-platform-engineering/) | The problem platforms solve; how PE differs from DevOps/SRE; the Thinnest Viable Platform. | Interview findings from 3 engineers. |
| 2 | [Platform as a Product](./02-platform-as-a-product/) | Product thinking for internal platforms; JTBD; measuring success. | A one-page Platform Product Brief. |
| 3 | [Developer Experience](./03-developer-experience/) | Cognitive load; measuring DX; golden paths; the friction taxonomy. | A "Time to Hello World in Production" audit. |
| 4 | [The Internal Developer Platform](./04-the-internal-developer-platform/) | The five planes of an IDP; reference architecture; build vs buy. | An IDP capability self-assessment. |
| 5 | [Platform Team Topology](./05-platform-team-topology/) | Team Topologies; interaction modes; avoiding the gatekeeper trap. | A Platform Team Charter. |

Work them in order — each builds on the last. Together they take you from "what is
this discipline?" to "here's how I'd structure a platform team and its first
product."

## Learning objectives

By the end of this phase you will be able to:

- Explain what platform engineering is, and how it differs from DevOps and SRE, in
  terms a skeptical engineer would accept.
- Apply product thinking — customers, jobs to be done, success metrics — to an
  internal platform.
- Define and measure developer experience, and identify the biggest sources of
  developer friction in an organization.
- Describe the reference architecture of an Internal Developer Platform and reason
  about build-vs-buy for its components.
- Design a platform team's structure, interaction modes, and charter so it enables
  rather than bottlenecks.

## Prerequisites

Just [Module 00 · Orientation](../00-orientation/). This phase is **concept and
discovery** work — there's nothing to install and no cloud spend. The labs are
real-world exercises (interviews, briefs, audits) that are most valuable if you do
them against a real organization you know, but every lab includes a worked
fictional scenario so you can complete it solo.

## A note on the labs

The foundations labs produce **artifacts you'll reuse**: the product brief, friction
audit, capability assessment, and team charter are exactly the documents a real
platform engineer writes in their first weeks on the job. Keep them — they're the
first entries in your platform engineering portfolio, and later technical projects
will make more sense when anchored to them.

---

Start with [**01 · What Is Platform Engineering? →**](./01-what-is-platform-engineering/)
