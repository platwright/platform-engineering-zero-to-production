<!-- markdownlint-disable MD033 -->
# Lab — Map the signals, feel the cardinality

> Observability starts as a *thinking* skill, not a tooling one. You will map RED,
> USE, and the four golden signals onto a concrete service, then run a tiny Python
> experiment that makes cardinality explosion visceral — so you never ship a
> `user_id` metric label by accident. No cluster, no cloud, just Python 3.

**Estimated time:** ~40–60 minutes
**Type:** Design + discovery
**Deliverable:** A completed [`signals-worksheet.md`](./signals-worksheet.md) and the
output of [`cardinality.py`](./cardinality.py) with your own label estimates.

## Objectives

- Translate a service into concrete RED, USE, and golden-signal measurements.
- Classify a question and pick the pillar (metric / log / trace) that answers it.
- Quantify how label choices drive metric cardinality — and cost.

## Prerequisites

- [Module 11.1](../README.md) theory.
- Python 3 (`python3 --version`) from
  [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md).
  No packages are required — the experiment uses only the standard library.
- Starter files in this folder: [`signals-worksheet.md`](./signals-worksheet.md) and
  [`cardinality.py`](./cardinality.py).

## Scenario

You operate a shared platform. One tenant runs `checkout`, a stateless HTTP service
with 50 replicas that calls a `payments` service and a Postgres database. You have
no special knowledge of its code — exactly the black box a platform team must still
observe. Everything below is about *what to measure*, not *how it was written*.

## Steps

1. **Map the service signals (RED).** Open
   [`signals-worksheet.md`](./signals-worksheet.md) and fill in Part A: for
   `checkout`, name the exact measurement you would collect for **Rate**, **Errors**,
   and **Duration**. Be specific — "requests per second **by route and status**,"
   not "traffic." State the unit and the labels you would attach.

2. **Map the resource signals (USE).** In Part B, do the same for the **node** the
   replicas run on: **Utilization**, **Saturation**, **Errors**. Note how these
   differ from RED — one watches the work, the other watches the machine.

3. **Fill the four golden signals.** In Part C, record **Latency, Traffic, Errors,
   Saturation** for the user-facing view of `checkout`. For latency, write down
   *which percentiles* you will report and why you split success from failure.

4. **Classify questions to pillars.** In Part D, for each of the five questions,
   mark whether you would reach for **metrics**, **logs**, or **traces** first — and
   justify it in a few words.

5. **Run the cardinality experiment.** Now make the cost real:

   ```bash
   python3 cardinality.py
   ```

   Read the output. The baseline label scheme produces a manageable series count;
   the "oops, we added `user_id`" line produces an absurd one. This is why the
   lesson insists identifiers belong in logs and traces, never in metric labels.

6. **Make it yours.** Edit the `labels` dictionary near the top of
   [`cardinality.py`](./cardinality.py) to match the estimates you wrote in Part A
   (your own route count and replica count), then re-run it. Record the resulting
   baseline series count and the `user_id` number in Part E of the worksheet, and
   answer: at what series count would you get nervous about a shared store?

7. **Draw the conclusion.** In Part F, write one sentence completing: *"Labels are
   for … and identifiers belong in … because …"* This single rule prevents the most
   expensive mistake in the phase.

## Expected result

A completed worksheet in which:

- Parts A–C contain concrete, labelled measurements (not vague words).
- Part D assigns a pillar to each question with a short justification.
- Part E records two series counts from your own run of `cardinality.py`.
- Part F states the labels-vs-identifiers rule in your own words.

Running `python3 cardinality.py` prints a baseline count in the low hundreds of
thousands and a `user_id` count in the hundreds of billions — the gap you must never
ship to production.

## Cleanup

> This lab creates no infrastructure, so there is nothing to tear down — the point of
> starting cheap. If you made a virtual environment, deactivate it; otherwise you are
> done.

```bash
# nothing to delete; the experiment was pure, local Python
# (if you created a venv:  deactivate)
echo "no infrastructure created — cleanup complete"
```

## Reflection

- How many of your five question-to-pillar choices were metrics? Notice how metrics
  tell you *that* something changed, but you almost always finish in logs or traces
  to learn *why*.
- Your worksheet is the seed of a dashboard. Which three panels would you build first
  for `checkout`, and would any of them have paged you for a *symptom* rather than a
  *cause*?
- The cardinality number scared you on purpose. Who, on a platform team, should own
  the limit that prevents a tenant from shipping that mistake?

## Stretch goals (optional)

- Extend [`cardinality.py`](./cardinality.py) to model a **histogram**: a latency
  histogram multiplies series by its **bucket count** (e.g. 12 buckets). Add a
  `buckets` factor and see how histograms cost more than counters.
- Add a second metric to the worksheet for the `payments` dependency and decide
  whether its errors should count against `checkout`'s error rate (hint: think about
  who the user blames).
- Write the one PromQL-shaped pseudo-expression you *expect* would compute
  `checkout`'s error rate from your Rate and Errors measurements. You will write the
  real thing in [Module 11.3](../../03-metrics-with-prometheus/).
