# Module 06.4 — Pipeline Templates as a Platform Product

> In Module 01 you learned that a platform is a *product* with customers. Here that
> idea gets concrete and technical: the pipeline itself is a product. The platform
> team owns, versions, and supports a golden-path pipeline template; application teams
> *consume* it with a few lines instead of writing CI from scratch. This module is
> about treating that template like software with users — versioning, migration,
> enforcement, escape hatches, and adoption metrics.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** [Module 06.3](../03-reusable-workflows-and-actions/) and a GitHub
account (free). The lab is local.

## Learning objectives

By the end of this module you will be able to:

- Explain why the platform team should **own the pipeline template** and developers
  should **consume** it.
- Design a **versioning and migration path** so template changes don't break consumers.
- **Enforce** the golden-path template for production without becoming a gatekeeper.
- Provide **escape hatches** that are legitimate, visible, and auditable.
- Define and measure **adoption** — the real scoreboard for a platform product.

---

## 1. Concept

### The template is the product

Left to themselves, every application team writes its own CI: a slightly different
build, a scanner someone forgot to add, a signing step nobody got around to. The
result is N subtly different pipelines and N different security postures. The platform
move is the one from Module 01.1's `new-service.sh`: **encode the paved road once.**
The platform team builds a reusable workflow — call it `app-ci@v2` — that does the
right things in the right order (lint → test → build → scan → sign → push), and app
teams consume it:

```yaml
jobs:
  ci:
    uses: platform-org/platform-workflows/.github/workflows/app-ci.yml@v2
    with:
      image-name: payments
    secrets: inherit
```

That is the whole of an app team's CI. They get the platform's security and
conventions *by default*, and the platform team can improve all of them at once.

### Consume, don't author

The point is not to hide YAML — it's to move the **responsibility**. When teams author
their own pipelines, the platform team can only *advise*. When teams consume a
template, the platform team can *guarantee*: "every production image is scanned and
signed" becomes a property of the template, not a hope about 50 repos. Developers trade
control they didn't want for cognitive load they're glad to shed — exactly the deal
platform engineering offers everywhere.

### Versioning and migration — you have users now

A template with consumers is an API. Break it and you break everyone. So you version it
and provide a migration path, like any product:

- **Semantic versions.** `v1`, `v1.1`, `v2`. A moving major tag (`v2`) lets consumers
  track non-breaking improvements automatically; a breaking change means a new major.
- **Deprecation, not deletion.** When `v2` lands, `v1` keeps working and starts emitting
  a deprecation warning with a migration link and a sunset date. You don't yank it.
- **Migration guides and codemods.** Tell consumers exactly what changed and, ideally,
  open the PRs for them (a bot that bumps `@v1` → `@v2` and adjusts inputs).
- **Changelogs.** Consumers plan around your releases; give them release notes.

```text
v1  ──(non-breaking)──► v1.1 ──► v1.2        (v1 tag follows along)
                                   │
 breaking change ──────────────► v2          (v1 still works; warns; sunset date set)
```

### Enforcement without gatekeeping

For production, "please use the template" isn't enough — but *mandating* it the wrong
way recreates the gatekeeper bottleneck Module 01 warned against. Enforce the
**outcome**, not the keystrokes:

- **Required workflows / org rulesets.** GitHub can require a given workflow to run on
  matching repos before merge.
- **Required status checks.** Branch protection requires the template's check names to
  pass before merge to `main`.
- **Provenance at the deployment gate.** The strongest option: the production
  environment only admits images **signed by the platform pipeline** (Module 06.5's
  Cosign step; verified by policy in Phase 13). A hand-rolled pipeline literally can't
  produce a deployable artifact, because it can't sign with the platform's identity.

The last one is the platform ideal: you don't police *how* teams build; you make the
paved road the only path that *reaches production*, because only it yields a signed,
admissible artifact.

### Escape hatches — opinionated, not mandatory

Real teams have legitimate exceptions: a service that genuinely can't run the slow
integration suite on every PR, a one-off that needs a different base image. A platform
that forbids all deviation gets routed around. So build **visible, auditable** escape
hatches:

- A typed input (`skip-integration-tests: true`) that is **off by default**, **logged**,
  and surfaced in an adoption/exception report.
- An exception process (a label + platform sign-off) for anything higher-stakes.
- A clean way to *extend* the template (pre/post hooks) rather than fork it.

The rule from Module 01: **opinionated defaults, not mandatory cages.** An escape hatch
you can see and count is far safer than teams silently forking the template.

### Adoption is the scoreboard

A gorgeous template nobody uses is a failed product. Measure adoption from day one:

- **What % of production services deploy via the golden-path pipeline?** (Count repos
  whose workflows `uses:` the template, or — better — count production images that carry
  the platform's signature.)
- **Escape-hatch rate.** How often is each hatch used? A spike means the default is wrong
  and the template needs to change — the hatch is a product-feedback signal.
- **Time-to-adopt a new version.** How long until consumers move from `v1` to `v2`?
  Slow migration means your migration path is too painful.

---

## 2. Why it matters for platform engineering

This module is where CI/CD stops being "a YAML file" and becomes platform product
management. The reusable-workflow mechanics from Module 06.3 are the *how*; this is the
*why and for whom*. Owning the template is the single highest-leverage thing a platform
team does in CI: one release improves security, speed, and consistency for every team
simultaneously — the leverage that justifies the platform team's existence.

It also reframes governance. Instead of chasing teams to adopt good practice, you make
good practice the path of least resistance and the only route to production. Enforcement
by provenance, escape hatches you can count, and adoption metrics are how you get
security and reliability *by default* while still treating developers as customers, not
subjects. This template is literally the pipeline Project 1 and Project 2 teams consume.

## 3. Mental model

```text
     THE PIPELINE TEMPLATE AS A PRODUCT
     ──────────────────────────────────

   PLATFORM TEAM (owns)                     APP TEAMS (consume)
   ┌───────────────────────────┐            ┌───────────────────────────┐
   │ app-ci@v2  (reusable wf)  │            │ uses: …/app-ci.yml@v2     │
   │  lint→test→build→scan→    │  ◄───────  │ with: { image-name: … }   │  × N repos
   │  sign→push                │  consume   │ (3 lines of CI, not 300)  │
   └───────────────────────────┘            └───────────────────────────┘
        │  releases: v1→v1.1→v2 (deprecate, don't delete; migration guide)
        │  enforce OUTCOME: prod admits only images SIGNED by this pipeline
        │  escape hatches: typed, default-off, logged, counted
        ▼
   ADOPTION METRIC  =  % of prod services on the golden path  ← the real scoreboard

   One line: own and version the template; enforce the outcome; keep hatches visible;
             measure adoption — a platform product, not a mandate.
```

## 4. Minimal implementation

The smallest "template as product" is a reusable workflow plus a three-line consumer.
Here's the consumer — the entire CI an application team maintains:

```yaml
# .github/workflows/ci.yml in an APPLICATION repo
on: [push, pull_request]
jobs:
  ci:
    uses: platform-org/platform-workflows/.github/workflows/app-ci.yml@v2
    with:
      image-name: payments
      # escape hatch intentionally NOT set -> integration tests run (safe default)
    secrets: inherit
```

And the product-shaped details that make it more than a shared file:

```text
- v2 is a MOVING major tag: consumers get non-breaking fixes automatically.
- app-ci@v1 still exists, prints a deprecation warning + migration link, sunsets 2025-12.
- The template emits `::notice::` telemetry on every run -> adoption dashboard.
- `skip-integration-tests: true` is possible, off by default, and `::warning::`-logged.
```

You'll build exactly this template and consumer in the lab, including the escape hatch
and the adoption-telemetry line.

## 5. Hands-on lab

You'll build `app-ci` — a golden-path reusable workflow that app teams consume — with a
typed, default-off **escape hatch** and an **adoption-telemetry** step. Then you'll write
the tiny consumer workflow an app team would maintain, validate both with `actionlint`,
and sketch how you'd measure adoption and enforce the template for production.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **Treat breaking changes as events.** Announce, provide a migration guide, open bump
  PRs, set a sunset date — and hold it. Surprise breakage destroys trust in the platform.
- **Enforce by provenance where you can.** Admitting only platform-signed images to prod
  is stronger and less annoying than policing how teams write YAML.
- **Instrument the template.** Emit per-run telemetry (service, version, hatch usage) so
  adoption and exceptions are dashboards, not guesses.
- **Make the hatch a feedback loop.** A frequently-used escape hatch is a bug report
  about your defaults — change the template, don't just tolerate the workaround.
- **Support it like a product.** Docs, a support channel, office hours, and a changelog.
  "Knowledge and support" are in the platform definition for a reason.
- **Version the template's own CI.** Test the template against canary consumers before
  moving the major tag; a broken `v2` breaks everyone at once.

## 7. Common mistakes

- **Mandating the template with no escape hatch** — teams fork it or route around it,
  and you lose visibility entirely. *Fix:* opinionated defaults plus visible, audited
  hatches.
- **Breaking consumers by editing in place** — changing `v2`'s behavior under everyone.
  *Fix:* semantic versions; breaking change → new major; deprecate the old one.
- **Enforcing keystrokes, not outcomes** — requiring a specific YAML shape teams can fake.
  *Fix:* enforce the outcome (signed, scanned artifact admitted to prod).
- **No adoption metric** — you can't tell if the product succeeded. *Fix:* measure % of
  prod services on the golden path and the escape-hatch rate.
- **Ignoring migration cost** — shipping `v2` with no guide or bump PRs; adoption stalls.
  *Fix:* migration guides, codemods/bots, and generous sunset windows.
- **Hiding the hatch instead of counting it** — an undocumented override everyone shares
  in Slack. *Fix:* make it a typed input that logs and reports.

## 8. Assessment

**Knowledge checks**

1. Why should the platform team *own* the pipeline template rather than each app team
   writing its own?
2. What is the difference between enforcing the *outcome* and enforcing the *keystrokes*,
   and why does provenance-based enforcement avoid gatekeeping?
3. How do you ship a breaking change to a template that has 50 consumers?
4. Give two properties a good escape hatch must have.
5. Name two adoption metrics and what a spike in escape-hatch usage tells you.

**Concept exercise**

> Explain why a pipeline template is a *product* **without using the words "pipeline,"
> "CI," or "YAML."** Describe who the customers are, what they consume, and how you'd know
> it succeeded.

**Trade-off / debugging exercise**

> Adoption of your `app-ci` template is stuck at 40%. Investigating, you find: teams on
> `v1` won't move because `v2` broke an input with no migration guide; three teams forked
> the template to skip a slow test because there's no supported way to; and you have no
> dashboard, so you only learned this by asking around. Diagnose each problem in
> product-management terms and give the fix.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Ownership turns advice into guarantees — the platform can ensure every prod
  image is scanned and signed, and improve all consumers with one release, instead of
  hoping each of N hand-rolled pipelines does the right thing.
- **Q2:** Outcome enforcement checks the *result* (a signed, scanned, admissible
  artifact); keystroke enforcement checks the *form* (a specific YAML), which teams can
  satisfy without the substance. Provenance (only platform-signed images reach prod) means
  the paved road is the only path that works, so you don't gatekeep *how* teams build.
- **Q3:** Cut a new major (`v2`), keep `v1` working with a deprecation warning and sunset
  date, publish a migration guide, and ideally open bump PRs for consumers.
- **Q4:** Default-off and visible/auditable (typed input, logged, counted) — plus
  ideally an approval path for higher-stakes exceptions.
- **Q5:** % of prod services on the golden path and time-to-adopt a new version; a spike
  in hatch usage means your default is wrong and the template should change.
- **Debugging:** (1) Breaking change without migration path → add a guide + bump PRs, and
  next time deprecate rather than break. (2) Forks to skip a test → add a supported,
  default-off escape hatch and track it. (3) No dashboard → instrument the template with
  per-run telemetry so adoption and exceptions are visible.

</details>

## 9. Further reading

- GitHub — [Reusing workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- GitHub — [Require workflows / organization rulesets](https://docs.github.com/en/actions/using-workflows/required-workflows)
- GitHub — [About protected branches and required status checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- CNCF — [Platforms White Paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/) (platform as a product)
- Team Topologies — [Platform as a product](https://teamtopologies.com/key-concepts) (thinnest viable platform, X-as-a-service)
- Thoughtworks — [Paved roads and golden paths](https://www.thoughtworks.com/insights/blog/engineering-effectiveness/platform-engineering-golden-paths)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 06.3 — Reusable Workflows and Composite Actions](../03-reusable-workflows-and-actions/) · _Next:_ [Module 06.5 — Container Build Pipelines](../05-container-build-pipelines/)
