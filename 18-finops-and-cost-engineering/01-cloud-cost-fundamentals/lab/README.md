# Lab — Build a cloud cost model

> You'll model a reference platform's monthly bill three ways — all on-demand, then a
> cost-optimized blend of committed and spot — and quantify the savings, using only a
> worksheet and a calculator. This is the "Inform" step of FinOps done on paper,
> before any tooling or cloud spend.

**Estimated time:** ~40–60 minutes
**Type:** Design (worksheet)
**Deliverable:** A completed [`cost-model-worksheet.md`](./cost-model-worksheet.md)
showing the all-on-demand bill, an optimized blend, and the percentage saved.

## Objectives

- Decompose a platform into its four cost components (compute, storage, network,
  managed services).
- Price compute three ways — on-demand, committed, spot — and justify the option per
  node group.
- Produce a single blended monthly figure and the savings versus naïve on-demand.

## Prerequisites

- [Module 18.1](../README.md) theory — the purchase options and cost components.
- A calculator or shell with `bc` (optional) — no cloud account needed.
- The starter worksheet: [`cost-model-worksheet.md`](./cost-model-worksheet.md).

## Scenario

You operate a small platform for three teams on a managed Kubernetes cluster. Model a
typical month from this inventory:

- **System node group** — 2 × (4 vCPU / 16 GB) at **\$0.19/hr**, runs 24/7 (ingress,
  logging, the platform's own components).
- **Web node group** — 3 × (8 vCPU / 32 GB) at **\$0.38/hr**; ~2 of the 3 are a steady
  floor, the 3rd only covers daytime spikes.
- **Batch node group** — up to 4 × (8 vCPU / 32 GB) at **\$0.38/hr** on-demand, running
  CI and nightly jobs that **tolerate interruption**.
- **Storage** — 800 GB of SSD persistent disk at **\$0.17/GB-month**.
- **Egress** — ~1.5 TB/month leaving to the internet at **\$0.12/GB**.
- **Managed services** — the control plane + a small managed database, flat
  **\$180/month**.

Assume ~**730 hours** in a month, a **−57%** 3-year committed discount, and a **−70%**
spot discount.

## Steps

1. **Copy the worksheet.** Work in a copy so the starter stays clean:

   ```bash
   cp cost-model-worksheet.md my-cost-model.md
   ```

2. **Price everything on-demand first.** Fill the "All on-demand" column for every row.
   The pattern for a compute row is `count × rate × hours`. For example the system
   group:

   ```text
   2 × $0.19 × 730 = $277.40 / month
   ```

   Do the same for the web group (all 3 nodes) and the batch group (assume an average
   of 3 nodes running). Add storage, egress, and managed services. Sum the column —
   this is your **naïve baseline**.

3. **Optimize the always-on floor with a commitment.** The system group and ~2 steady
   web nodes run 24/7, so they are safe to commit. Recompute those rows with the −57%
   discount (multiply the on-demand figure by `0.43`) and put the result in the
   "Optimized" column:

   ```bash
   echo "277.40 * 0.43" | bc -l     # system group, committed
   ```

4. **Leave genuine fluctuation on-demand.** The 3rd web node only covers daytime
   spikes, so keep it on-demand in the optimized column (committing it would waste the
   discount). Note *why* next to the row — the justification is half the deliverable.

5. **Move interruptible work to spot.** The batch group tolerates interruption, so
   price it at the −70% spot rate (multiply by `0.30`) in the optimized column:

   ```bash
   echo "(3 * 0.38 * 730) * 0.30" | bc -l    # batch group, spot
   ```

6. **Carry storage, egress, and managed services across unchanged.** These aren't
   compute-purchase decisions here, so copy the same figures into the optimized column
   (you'll attack storage tiering and egress in Module 18.4).

7. **Total both columns and compute the saving.** Sum the optimized column, then:

   ```bash
   # replace with your own totals
   echo "scale=1; (1 - OPTIMIZED/BASELINE) * 100" | bc -l
   ```

   Record the baseline total, the optimized total, and the percentage saved in the
   summary box.

8. **(Optional, needs a browser only) sanity-check one rate.** Open a public pricing
   calculator — the [AWS Pricing Calculator](https://calculator.aws/) or the
   [Google Cloud calculator](https://cloud.google.com/products/calculator) — and look
   up one comparable instance. You don't need an account. Note whether the list price
   is in the same ballpark as the lab's \$0.38/hr and how much a committed/spot option
   moves it.

## Expected result

A completed worksheet in which:

- The **all-on-demand** total lands near **\$2,000/month** (your arithmetic will vary
  slightly with the batch average you chose).
- The **optimized** blend is roughly **30–40% lower**, driven almost entirely by
  committing the floor and putting batch on spot.
- Every node group has a one-line **justification** for its purchase option, and
  egress/storage are visible line items rather than afterthoughts.

You now have a defensible cost model you could present before provisioning anything —
the FinOps habit of *modeling cost before incurring it*.

## Cleanup

> This lab creates **no cloud resources** — that is the point of modeling first. There
> is nothing to tear down and nothing was billed.

```bash
# Optional: remove your working copy if you don't want to keep it
rm -f my-cost-model.md
```

Keep the completed worksheet in your portfolio — it's the first artifact of the
"Inform" phase and you'll revisit its assumptions after measuring real usage in
Module 18.2.

## Reflection

- Which single change saved the most — committing the floor or moving batch to spot?
  Why does that depend on how much of your fleet is genuinely "always on"?
- Egress and storage survived your optimization untouched. What would you have to know
  about the workload to attack them, and where would you get that data?
- Your model assumed the batch group averages 3 nodes. How sensitive is the final
  number to that guess, and what does that tell you about the value of *measuring*
  instead of estimating?

## Stretch goals (optional)

- Add a **blended effective rate** row: total compute cost ÷ total vCPU-hours. This is
  the number you should actually reason with, not the list price.
- Model a **multi-region** variant: duplicate the web tier in a second region and add
  the cross-region egress between them. Watch egress become a top-three line item.
- Re-run the model assuming the batch group's commitment risk changed — what if only
  50% of batch capacity can safely run on spot? Show the new total.
