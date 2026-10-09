# Lab — Developer Pain Discovery

> Your first platform engineering skill is **product discovery**, not YAML. In this
> lab you'll interview engineers about the pain of deploying and operating their
> services, then find the recurring themes. This is the raw material every good
> platform is built from.

**Estimated time:** ~60–90 minutes
**Type:** Discovery
**Deliverable:** A short findings document ([`findings-template.md`](./findings-template.md))
summarizing three interviews and the top recurring themes.

## Objectives

- Practice interviewing developers about their real workflow pain.
- Separate **symptoms** ("the deploy failed") from **root causes** ("no one knows
  which of the 14 YAML files is the source of truth").
- Identify recurring themes — the signal a platform should target first.

## Prerequisites

- None technical. Access to three engineers is ideal; if you don't have that, use
  the **solo option** below.

## Steps

1. **Pick three interviewees.** Ideally engineers who regularly deploy and operate
   a service — different teams if possible, so themes that recur are meaningful.
   (No access to three people? Use the [solo option](#solo-option).)

2. **Run each interview (~15 min).** Use [`interview-guide.md`](./interview-guide.md)
   as your script. The one question you must ask:

   > *"What is the most painful part of deploying and operating your service?"*

   Then **follow the pain.** Keep asking "why?" and "what happens then?" until you
   reach a root cause, not just a symptom. Take notes in the interviewee's own
   words — verbatim quotes are gold.

3. **Capture each interview** in the findings template: who they are, their top
   pains, and memorable quotes.

4. **Synthesize.** Across all three, look for **themes** — pains that showed up more
   than once, or different symptoms with the same root cause. Rank them by how
   often they appeared and how much they hurt.

5. **Name the single biggest opportunity.** If you could remove *one* source of
   friction for these engineers, which would deliver the most value? Write down why.

## Expected result

A completed [`findings-template.md`](./findings-template.md) containing:

- Three interview summaries with at least one verbatim quote each.
- A ranked list of recurring themes.
- One clearly identified "biggest opportunity" with a short justification.

You're done when someone who wasn't in the interviews could read your findings and
understand what hurts most and why.

## Reflection

- How many of the pains were about **tools**, and how many about **missing
  knowledge, unclear ownership, or waiting on other people**? (Platforms address
  all three — not just tools.)
- Did the stated pain match the *root* pain? Where did "why?" change your
  understanding?
- Notice: you now have the start of a **platform roadmap** grounded in evidence —
  the opposite of "build it and they will come."

## Stretch goals (optional)

- Interview a fourth person from a *different* role (a manager, an SRE). Do the
  themes shift?
- Translate your top theme into a one-sentence problem statement you could hand to
  Module 01.2's Platform Product Brief.

---

## Solo option

No access to three engineers? Use these three (fictional but realistic) interview
transcripts and do **steps 3–5** on them. Treat them as your raw notes.

> **Priya — Senior Backend Engineer, Payments team**
> *"The worst part? Standing up a new service. I copy the deployment YAML from our
> last service, change names in about ten places, and inevitably miss one. Last
> time the service came up but had no resource limits, got OOM-killed in prod at
> 2am, and I found out from an angry customer, not an alert. Nobody can tell me
> which repo is the 'correct' template."*

> **Marco — Full-stack Engineer, Growth team**
> *"Deploying is fine once it's set up. My pain is **not knowing if it worked**.
> After I deploy I'm clicking through three different dashboards and tailing logs
> by hand to convince myself it's healthy. And setting up a dashboard for a new
> service is a day of copy-pasting Grafana JSON I don't understand."*

> **Aisha — Engineer, new hire on the Orders team (3 weeks in)**
> *"Getting my first change to production took **nine days**. Most of that was
> waiting: a ticket for cloud access, a ticket for a database, a Slack thread to
> find out how secrets work, and a code review from a platform person who was on
> vacation. The actual code change was an afternoon."*

Work the synthesis: What themes recur across Priya, Marco, and Aisha? (Hint: look
for *inconsistent/unknown "right way,"* *lack of feedback after deploy,* and
*waiting on humans for routine things.*) Which single opportunity would you target
first, and why?

> Keep your completed findings — Module 01.2 turns the top opportunity into a
> Platform Product Brief, and Module 01.3 measures one of these pains directly.
