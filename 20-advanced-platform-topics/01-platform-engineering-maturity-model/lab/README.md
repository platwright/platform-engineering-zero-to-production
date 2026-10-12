# Lab — Platform Maturity Self-Assessment

> Assess a platform across eight dimensions, defend each rating with evidence,
> produce a maturity profile, and turn it into a prioritized next-step plan. This is
> the exact exercise a platform lead runs to set a quarter's direction.

**Estimated time:** ~45–70 minutes
**Type:** Design / assessment
**Deliverable:** A completed [maturity self-assessment worksheet](./maturity-self-assessment-worksheet.md) with a per-dimension profile, an overall characterization, and a one-item next-step plan.

## Objectives

- Rate a platform 1–5 on each of eight dimensions, citing observable evidence.
- Produce a **profile** (a bar across dimensions), not a single averaged score.
- Identify the **lowest painful bar** and write a concrete, evidence-based next step.
- Practice assessing honestly — the way maturity models earn their keep.

## Prerequisites

- [Module 20.1 theory](../README.md) — the five levels and the eight dimensions.
- Ideally a **real platform you know** (your employer's, a past job's, an open-source
  project's). No real platform handy? Use the **"Northwind" worked scenario** in the
  worksheet — it is a complete fictional platform you can assess end to end.
- Nothing to install. This is a paper (or Markdown) exercise.

## Steps

1. **Copy the worksheet.** Open
   [`maturity-self-assessment-worksheet.md`](./maturity-self-assessment-worksheet.md)
   and copy it to a working file (for a real assessment, keep it with your platform
   docs). It already lists the eight dimensions and the level descriptors.

2. **Gather evidence before you grade.** For each dimension, write down one or two
   *observable* facts first — a ticket queue length, a pipeline, a dashboard, an
   adoption percentage, a survey result, a "time-to-environment" number. Resist
   grading from memory or optimism.

   ```text
   Self-service: "A new namespace still requires a platform-team ticket; median
   turnaround ~2 days." → that is the evidence, recorded before the number.
   ```

3. **Rate each dimension 1–5** using the descriptors, and write the *evidence* in the
   cell next to the number. The rule: if you cannot cite something observable, you do
   not get to claim the level. When unsure between two levels, pick the **lower** one
   — maturity is what you can defend, not what you aspire to.

4. **Draw the profile.** Fill the simple text bar chart in the worksheet so the shape
   is visible at a glance. The point is to *see* that the platform is uneven — strong
   here, weak there — which a single score would hide.

5. **Characterize the platform in one honest sentence.** Something like *"a Level 3
   self-service platform with a Level 1 cost blind spot and no reliability practice of
   its own."* This is what you would tell a director.

6. **Pick the one next step.** Find the **lowest bar that is causing real pain** (not
   simply the lowest number). Write a concrete next step: the capability to build, the
   phase of this course it draws on, the target level, and how you will know it moved.

   ```text
   Next step: Cost is L1 and causing monthly budget surprises.
     Build: OpenCost + a per-team weekly showback report (Phase 18).
     Target: Cost L1 → L2 this quarter.
     Signal: every team can see its own weekly spend; finance stops escalating.
   ```

7. **Sanity-check for rung-skipping.** Confirm your next step does not depend on a
   lower rung you have not reached. If it does (e.g. "add an AI copilot" while
   self-service is L2), pick the prerequisite instead.

## Expected result

A completed worksheet that contains, for a real or fictional platform:

- Eight dimensions rated 1–5, each with a one-line **evidence** citation.
- A visible **profile** showing the platform is uneven.
- A one-sentence honest **characterization**.
- A single, concrete, prerequisite-respecting **next step** with a target and a
  success signal.

A colleague should be able to read it in two minutes and understand where the
platform stands and what you will do next — and *why*.

## Cleanup

> Nothing to tear down — this is a pure design/assessment lab with no running
> resources and no cloud spend. Keep the completed worksheet; it is a portfolio
> artifact and the baseline you will re-assess against next quarter.

## Reflection

- Which dimension were you most tempted to over-grade? What evidence kept you honest?
- Did the **profile** change your sense of priority compared to a single score?
- Is your next step the lowest *painful* bar, or just the lowest number? They are not
  always the same.
- If you assessed a real platform: who else should be in the room next time to keep
  the grading honest?

## Stretch goals (optional)

- **Re-run it with a stream engineer.** Have someone who *consumes* the platform grade
  the same dimensions independently, then compare. The gaps are gold.
- **Map to the CNCF model.** Translate your eight-dimension profile onto the CNCF
  Platform Engineering Maturity Model's dimensions (Investment, Adoption, Interfaces,
  Operations, Measurement) and note what each framework surfaces that the other hides.
- **Sketch a two-quarter climb.** Sequence three next steps across two quarters,
  respecting prerequisites, and write the one-line before/after story you would tell
  leadership at the end.
