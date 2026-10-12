# Lab — Design an AI-Assisted Platform Capability

> Choose one AI-assisted capability and design it responsibly on a single-page
> canvas: the job it serves, its level of autonomy, the human-in-the-loop
> checkpoints, the guardrails, the failure modes, and how you'd evaluate it — before
> any integration code exists.

**Estimated time:** ~45–60 minutes
**Type:** Design
**Deliverable:** A completed [AI-capability design canvas](./ai-capability-design-canvas.md) for one capability, with an explicit autonomy level and guardrails.

## Objectives

- Pick a capability where AI's "draft / summarize / translate" shape genuinely fits.
- Place it on the **levels-of-autonomy** ladder and justify that placement.
- Specify the **human-in-the-loop** checkpoint and the **guardrails** that contain it.
- Name the failure modes (hallucination, prompt injection, data leakage) and their
  controls, and define how you'd **evaluate** the capability.

## Objectives check — pick a good candidate

Strong first candidates (low risk, clear value):

- An **AIOps incident summarizer** that reads the current incident's logs/alerts and
  produces a summary + correlated-alert list — **read-only (L1)**.
- **AI-drafted runbooks** synthesized from the last N incidents of a given alert —
  drafts a doc a human reviews before publishing.
- A **natural-language self-service on-ramp** that maps intent onto one of a fixed
  menu of existing golden paths — **draft-action (L2)**.
- **Explained right-sizing** suggestions from 30 days of usage (Phase 18) — opens a
  PR a human merges (**L2/L3**).

## Prerequisites

- [Module 20.2 theory](../README.md) — the four areas, the autonomy ladder, and the
  trust boundary.
- Helpful context: [Module 01.3 Developer Experience](../../../01-platform-foundations/03-developer-experience/)
  (golden paths), [Phase 13 Security & Policy](../../../13-security-and-policy-engineering/)
  (guardrails), and [Phase 11 Observability](../../../11-observability-engineering/)
  (the data AIOps reads).
- Nothing to install. This is a design exercise — no AI account, no cloud spend.

## Steps

1. **Copy the canvas.** Open
   [`ai-capability-design-canvas.md`](./ai-capability-design-canvas.md) and copy it
   to a working file.

2. **State the job to be done.** In the JTBD form from
   [Module 01.2](../../../01-platform-foundations/02-platform-as-a-product/):
   *"When `<situation>`, I want to `<motivation>`, so I can `<outcome>`."* If you
   can't phrase a real job, pick a different capability — AI looking for a problem is
   an anti-pattern.

3. **Place it on the autonomy ladder (L1–L4).** Write the level and one sentence of
   justification tied to blast radius. Default to the lowest level that still
   delivers the value. Anything that writes to production should be **L2**.

4. **Draw the trust boundary.** Note what *untrusted input* the AI sees (prompts,
   logs, alerts), what it is allowed to *emit* (free text? a fixed menu of actions?),
   and what standing authority it has (ideally **none**).

5. **Define the human-in-the-loop checkpoint.** Exactly where does a human review,
   approve, or edit? Who is **accountable** for the outcome? ("The AI" is never a
   valid answer.)

6. **List failure modes and controls.** For each of hallucination, prompt injection,
   data leakage, and non-determinism, write the specific control (schema-constrained
   output, read-only, redaction/no-training model, pinned action for review, least
   privilege, audit log).

7. **Define evaluation + fallback.** How will you measure whether it helps —
   acceptance rate, correction rate, incidents caused? And what happens when the
   model is down, slow, or wrong (the golden path must still work)?

8. **Red-team it in one line.** Write the single nastiest thing an adversary (or a
   buggy service) could try, and confirm your guardrails stop it. If they don't, lower
   the autonomy level or remove the AI's authority.

## Expected result

A one-page canvas that a skeptical staff engineer could read and agree is
**responsible**: a real job, the lowest justified autonomy level, an explicit human
gate on any write, a constrained output and least-privilege (ideally zero-authority)
AI, named failure modes with controls, an evaluation plan, and a fallback. It should
be obvious from the page *who is accountable* and *why the AI can't cause harm on its
own*.

## Cleanup

> Nothing to tear down — this is a pure design lab with no running resources and no
> cloud spend. Keep the canvas; it's a portfolio artifact and a template you can
> reuse for the next capability.

## Reflection

- Did forcing a **JTBD** change (or kill) your capability idea? AI without a real job
  is a solution looking for a problem.
- Is your capability a new *interface* to an existing golden path, or is it secretly
  *replacing* a golden path you never built?
- Where did you put the human gate — and would you still defend that placement if the
  AI's suggestion were wrong 1 time in 20?
- What would it take to move *up* one autonomy level safely? What evidence would you
  need first?

## Stretch goals (optional)

- **Write the output schema.** Draft the exact JSON schema the AI must emit for an
  L2 self-service action, and the validation that rejects anything off-menu.
- **Design the evaluation harness.** Specify how you'd log prompts, resolved actions,
  approvals, and outcomes, and the dashboard panel that shows acceptance rate over
  time (ties into [Module 20.3](../../03-platform-engineering-metrics/)).
- **Map it to maturity.** Note which maturity dimension (Module 20.1) this capability
  advances, and confirm the prerequisites for that level are already in place.
