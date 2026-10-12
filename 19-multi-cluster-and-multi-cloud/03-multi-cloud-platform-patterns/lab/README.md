# Lab — Decide multi-cloud honestly

> A **decision lab**, not a build. You'll read a Crossplane **XRD** and **two
> Compositions** (AWS S3 and GCP GCS) that back a single `ObjectBucket` developer API, and
> find exactly where the portability abstraction leaks. Then you'll complete a **multi-cloud
> decision worksheet** for a scenario — name the driver, estimate the cost premium, and
> choose a point on the portability-ready ↔ actively-multi-cloud dial — and write a one-line
> recommendation you could defend to a CTO.

**Estimated time:** ~45–60 minutes
**Type:** Design / decision
**Deliverable:** A completed [`multi-cloud-decision-worksheet.md`](./multi-cloud-decision-worksheet.md)
with a written recommendation, plus notes on where the XRD abstraction leaks.

## Objectives

- Read a real portability abstraction (one XRD, two Compositions) and judge its honesty.
- Identify the lowest-common-denominator tax in a concrete API.
- Apply a decision framework: driver, cost premium, and position on the dial.
- Produce a defensible multi-cloud recommendation for a scenario.

## Prerequisites

- [Module 05.6 · Crossplane](../../../05-infrastructure-as-code/06-crossplane/) — XRDs,
  Compositions, and claims.
- [Phase 14 · FinOps](../../../18-finops-and-cost-engineering/) — enough cost intuition to
  reason about egress and the lowest-common-denominator tax.
- No cloud accounts and no tools are required — this is pen-and-paper (well, Markdown).
- Starter files: [`xrd-objectstorage.sketch.yaml`](./xrd-objectstorage.sketch.yaml),
  [`composition-aws-s3.sketch.yaml`](./composition-aws-s3.sketch.yaml),
  [`composition-gcp-gcs.sketch.yaml`](./composition-gcp-gcs.sketch.yaml), and
  [`multi-cloud-decision-worksheet.md`](./multi-cloud-decision-worksheet.md).

## Steps

1. **Read the developer-facing API.** Open
   [`xrd-objectstorage.sketch.yaml`](./xrd-objectstorage.sketch.yaml). This is the *one*
   API both clouds present: an `ObjectBucket` claim with a tiny schema. Notice how little a
   developer specifies — and that nothing in it names a cloud.

2. **Read the two implementations.** Open
   [`composition-aws-s3.sketch.yaml`](./composition-aws-s3.sketch.yaml) and
   [`composition-gcp-gcs.sketch.yaml`](./composition-gcp-gcs.sketch.yaml) side by side. The
   same `XObjectStorage` is backed by an S3 bucket (plus its versioning and public-access
   settings) or a GCS bucket (plus its IAM and versioning). This is the multi-cloud
   abstraction: one contract, a Composition per cloud.

3. **Find where the abstraction leaks.** In the worksheet's "Abstraction leak audit", list
   at least three things that do **not** map cleanly between S3 and GCS (for example:
   bucket-naming rules, per-object vs bucket IAM, storage-class names, lifecycle rules,
   encryption options). Each leak is either hidden (lowest-common-denominator — a feature you
   can't offer) or exposed (a cloud-specific field that breaks portability). Classify each.

4. **Pick a scenario and name the driver.** In the worksheet, choose scenario A, B, or C
   (or your own org). Write the multi-cloud driver in **one sentence**. If it does not name
   an external constraint (regulation, acquisition, a unique service, provider-failure DR),
   mark it **weak** — that is a finding, not a failure.

5. **Estimate the cost premium.** Fill the cost table: duplicated expertise and tooling,
   inter-cloud networking, monthly egress, and the lowest-common-denominator tax. You are
   after an order of magnitude, not accounting precision — enough to compare against the
   value of the driver.

6. **Place yourself on the dial and recommend.** Choose single-cloud, portability-ready, or
   actively-multi-cloud, and write the one-line recommendation with its top two
   justifications. For most scenarios the honest answer is portability-ready — be ready to
   say so even when the scenario *sounds* like it wants more.

## Expected result

A completed `multi-cloud-decision-worksheet.md` in which:

- the driver is stated in one sentence and classified real or weak,
- the abstraction leak audit lists at least three concrete S3/GCS mismatches,
- the cost table gives rough figures for each premium, and
- a one-line recommendation names a position on the dial with two justifications.

You should be able to defend the recommendation against "but we need to avoid lock-in."

## Cleanup

> This lab creates **no cloud resources** — the sketches are illustrative and are not meant
> to be applied. Nothing to tear down.

```bash
# Optional: if you experimented by applying the XRD to a throwaway kind cluster with
# Crossplane installed, remove it (the Compositions need real cloud providers to do anything):
# kubectl delete -f xrd-objectstorage.sketch.yaml --ignore-not-found
# kind delete cluster --name crossplane-test
```

## Reflection

- Your leak audit found features that do not map between clouds. For each, which is worse for
  *your* scenario — hiding it (losing capability) or exposing it (losing portability)?
- The worksheet asked for an egress estimate. Where in a realistic design does cross-cloud
  traffic hide, and how would you redesign to shrink it?
- You likely landed on portability-ready. Articulate the cheapest concrete steps that deliver
  most of multi-cloud's benefit (reduced switching cost) without its cost.

## Stretch goals (optional)

- Add a third Composition sketch for Azure Blob Storage and re-run the leak audit — does the
  lowest-common-denominator shrink further with a third cloud?
- Extend the XRD with a `storageClass` field and decide how to map `standard` / `nearline` /
  `cold` across clouds without leaking provider names.
- Price your scenario's egress properly using a current cloud data-transfer calculator and
  compare it to the compute cost — which dominates, and what does that imply?
- Write a one-paragraph ADR (using the repo's ADR template) recording the decision, so the
  next engineer inherits the reasoning, not just the result.
