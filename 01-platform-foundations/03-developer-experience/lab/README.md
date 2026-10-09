# Lab — Time to Hello World in Production

> Measure, end to end, how long it takes a brand-new team to get a trivial change
> ("hello world") into production — counting every command, ticket, and wait. This
> single audit reveals more about an organization's developer experience than any
> dashboard, and it hands you a prioritized friction list.

**Estimated time:** ~45–60 minutes
**Type:** Discovery / measurement
**Deliverable:** A completed [worksheet](./time-to-hello-world-worksheet.md) with a
total time, a wait-vs-active breakdown, and the top three *avoidable* frictions.

## Objectives

- Trace a real end-to-end path from "I have a change" to "it's live and healthy."
- Separate **active work** from **waiting**, and **essential** from **avoidable**
  friction.
- Produce an evidence-based shortlist of the highest-leverage DX improvements.

## Steps

1. **Choose the journey.** A *new team* (or new hire) shipping a trivial service
   that prints "hello world" to production. Use a real organization you know, or the
   [fictional scenario](#fictional-scenario) below.

2. **List every step** from "I have the change" to "it's running in production **and
   I can confirm it's healthy**." Don't skip the boring parts — getting access,
   finding the right repo, asking someone how secrets work. The boring parts are
   usually where the time goes.

3. **For each step, record** (in the worksheet):
   - elapsed time,
   - whether it was **active work** or **waiting**,
   - who you depended on (self / another team / an approval),
   - the **friction type** (setup / deploy / ops / debug / waiting).

4. **Total it up.** Compute total elapsed time and the **wait vs. active** split.
   The split is often the headline: most of the clock is usually *waiting*.

5. **Mark essential vs. avoidable.** Some friction is legitimate (e.g. a real
   security review for a sensitive system). Most is accidental. Be honest about
   which is which.

6. **Pick the top three avoidable frictions** — biggest time sinks you could remove
   with a golden path or self-service — and note how you'd address each.

## Expected result

A completed worksheet showing: the full step list, a total time, the wait/active
breakdown, and three prioritized, *avoidable* frictions with proposed fixes. Someone
reading it should immediately see where the days go.

## Reflection

- How much of the total was **waiting** vs **active work**? Did that surprise you?
- How many steps required **another human**? Each is a candidate for self-service.
- Which of your top-three map to the capabilities in your Module 01.2 brief? (They
  should reinforce each other.)

## Stretch goals (optional)

- Estimate the **"golden path" time**: how long *could* this take if every avoidable
  friction were removed? The gap is your opportunity size.
- Re-run the audit for a *second* journey ("add a new environment variable to an
  existing service") and compare the friction profile.

---

## Fictional scenario

Use this if you don't have a real organization to audit. It's the world of
Priya/Marco/Aisha from Module 01.1. Your job is to lay out the steps, time them, and
classify them in the worksheet.

> **"HelloCorp," a 60-engineer company.** A new hire, **Sam**, must ship a service
> that returns "hello world" at `/` to production. What actually happens:
>
> - Day 1: Sam asks in Slack how to start a new service. Gets three different
>   answers. Picks one (copy an existing repo). *(setup; active + waiting)*
> - Day 1–2: Copies another team's repo, renames things in ~10 files, guesses at the
>   deployment YAML. *(setup; active)*
> - Day 2: Needs cloud access → files a ticket. *(waiting)*
> - Day 4: Access granted. Needs a dev namespace → asks the platform person, who is
>   out until Day 6. *(waiting)*
> - Day 6: Namespace created. Secrets? Another Slack thread to learn the convention.
>   *(ops; waiting)*
> - Day 7: First deploy to dev. No dashboard; Sam tails logs by hand to check it's
>   up. *(debug; active)*
> - Day 7–8: Production deploy needs a review from the platform team (required). The
>   reviewer is busy; it lands Day 8. *(deploy; waiting + essential?)*
> - Day 8: It's live. Sam isn't sure it's healthy — clicks through two dashboards to
>   convince themselves. *(debug; active)*
>
> **Total: ~8 working days to print "hello world."** Lay these steps into the
> worksheet, compute the wait/active split, mark essential vs avoidable, and choose
> the top three avoidable frictions to fix first.

<details>
<summary>Hint: what the top three usually are here</summary>

1. **No golden path for new services** (setup) → a `new-service` template + docs.
2. **Waiting on humans for routine access/namespaces/secrets** (waiting/ops) →
   self-service provisioning.
3. **No deploy health feedback** (debug) → default dashboard + readiness checks in
   the template.

The required production review may be *essential* friction — keep it, but make it
fast (clear checklist, backup reviewers).

</details>
