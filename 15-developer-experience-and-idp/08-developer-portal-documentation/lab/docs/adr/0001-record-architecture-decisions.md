# ADR 0001 — Record architecture decisions

## Status

Accepted

## Context

We make architectural decisions throughout the life of this service — which datastore
to use, how to handle retries, where a boundary sits. Months later, the *reasons*
behind those choices are forgotten, so they get second-guessed or silently reversed,
and the original trade-offs are re-learned the hard way.

We want a lightweight, durable record of *why* significant decisions were made, kept
with the code and reviewed like code.

## Decision

We will record significant architectural decisions as **Architecture Decision Records
(ADRs)** stored in `docs/adr/`, one Markdown file per decision, numbered sequentially.

Each ADR captures: **Status**, **Context**, **Decision**, and **Consequences**. ADRs
are **append-only** — a superseded decision is not edited; a new ADR is written that
references and supersedes it.

## Consequences

- The *why* behind the architecture is preserved and discoverable in the portal
  (TechDocs), not just the *what* in the code.
- New maintainers can read the decision history instead of reverse-engineering intent.
- There is a small, worthwhile cost: writing an ADR for each significant decision and
  reviewing it in the pull request that introduces the change.
- We need a convention for what counts as "significant" to avoid both over- and
  under-recording.
