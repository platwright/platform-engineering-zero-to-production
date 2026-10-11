# Lab — Measure your platform toil

> You will run a **toil audit** on a platform team: inventory its operational tasks,
> classify each against the six-point toil test, quantify toil as a fraction of team
> time, and produce a **ranked automation backlog**. The output is the artifact an
> SRE lead brings to sprint planning to justify automation work. No cluster required.

**Estimated time:** ~45–60 minutes
**Type:** Discovery / measurement
**Deliverable:** A completed [`toil-inventory-worksheet.md`](./toil-inventory-worksheet.md)
with a toil fraction and a prioritized automation backlog.

## Objectives

- Inventory a platform team's recurring operational work.
- Classify each task as **toil** or **engineering** using the six-point test.
- Quantify toil as a percentage of team time.
- Rank toil by cost and turn it into an automation backlog.

## Prerequisites

- [Module 17.1](../README.md) theory (the six-point toil test).
- A copy of the worksheet in this folder:
  [`toil-inventory-worksheet.md`](./toil-inventory-worksheet.md). It contains a
  **worked fictional scenario** (a one-week log for a 4-person platform team) so you
  can complete the lab solo, plus a blank section for a real team if you have one.
- No tools or cloud. A text editor and, optionally, `bc` or a spreadsheet for the
  arithmetic.

## Steps

1. **Open the worksheet and read the scenario.** Copy it so you can edit freely:

   ```bash
   cd 17-platform-sre/01-platform-sre-fundamentals/lab
   cp toil-inventory-worksheet.md my-toil-audit.md
   ```

   The scenario lists a week of work for the "Internal Platform" team: namespace
   onboarding, secret rotations, a stuck-operator restart, a cluster upgrade, an
   on-call page, and some project work.

2. **Classify each task.** For every row, mark it **toil** or **engineering** by
   applying the six-point test from the lesson: is it manual, repetitive,
   automatable, reactive, value-less *after* it is done, and does it scale with
   growth? Writing the upgrade *runbook* is engineering; running the *same* namespace
   setup for the eighth time is toil. Record a one-line reason for each call — the
   reasoning is the point.

3. **Quantify each toil task.** Fill in `minutes × times-this-week = toil-minutes`
   for every task you marked as toil. Be honest about frequency; the tasks that
   happen often are usually the real problem even when each instance is short.

4. **Compute the toil fraction.** Sum the toil-minutes and divide by the team's
   available minutes for the week:

   ```bash
   # Example: 4 engineers × 30 productive hours/week = 7200 available minutes
   echo "scale=3; TOIL_MINUTES / (4*30*60)" | bc
   ```

   Compare the result to the ~50% cap. Is this team sustainable, or are they bailing
   water?

5. **Rank the toil.** Sort your toil categories by total minutes (cost), not by how
   annoying they feel. The most expensive category goes to the top of the backlog.

6. **Write the automation backlog.** For each top toil category, name the automation
   that removes it and roughly what it would save per week. Map each to something you
   built earlier in the course where possible (GitOps templates, External Secrets
   Operator, cert-manager, a liveness probe + runbook). This ordered list is your
   deliverable.

7. **(Optional) Run it on a real team.** Use the blank table at the bottom of the
   worksheet to log one real sprint of your own team's work and repeat steps 2–6.
   Real data is far more persuasive in planning than the fictional scenario.

## Expected result

A completed worksheet containing: every task classified with a reason, a computed
toil fraction (for the scenario it lands well above a healthy level), a ranked list
of toil categories by cost, and a 3–5 item automation backlog where each item names
the toil it kills and its estimated weekly saving. You should be able to point at the
number one item and justify it with hours, not opinion.

## Cleanup

> This lab creates no cloud resources — nothing to tear down. Keep the worksheet.

```bash
# Nothing to delete. Your completed audit is a portfolio artifact — keep it.
# If you made a working copy you no longer want:
# rm -f my-toil-audit.md
```

## Reflection

- Which single automation would most improve this team's sustainability, and how did
  the *numbers* (not your gut) point you to it?
- The scenario's toil fraction is high. If you did nothing, what happens to it as the
  platform onboards ten more teams next quarter — and why?
- Writing the upgrade runbook was engineering, but running the upgrade by hand was
  toil. Where exactly is the line, and what would move the manual upgrade across it?

## Stretch goals (optional)

- Turn the worksheet into a recurring ritual: track the toil fraction for three
  sprints and plot the trend. A rising line is an early warning.
- Add a column estimating `build + maintain` cost for each automation and compute a
  simple payback period (`weekly-saving ÷ build-cost`). Re-rank by payback. Does the
  order change?
- Extend the six-point test with a seventh column, "how many teams does a failure
  here block?", and use it to weight critical-path toil (registry, Argo CD) above
  conveniences.
