# Module 07.4 — Helm vs Kustomize

> Helm and Kustomize are constantly framed as rivals. They're not — they solve
> overlapping problems with opposite philosophies: Helm **generates** manifests from
> templates and packages them for distribution; Kustomize **patches** manifests that
> already exist, with no templating. This module gives you a decision framework for
> which to reach for, and shows how to **combine** them instead of picking a side.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** [Module 07.2](../02-helm-chart-development/) and [Module 07.3](../03-kustomize/), `kubectl` + [kind](https://kind.sigs.k8s.io/), and [Helm](https://helm.sh/).

## Learning objectives

By the end of this module you will be able to:

- Contrast Helm's **templating + packaging** with Kustomize's **patching + overlays**.
- Decide, for a given job, when Helm wins and when Kustomize wins.
- Combine them: a Helm chart as the base, a Kustomize overlay for environment deltas.
- Explain how Argo CD consumes both, and what that means for GitOps (Phase 8).

---

## 1. Concept

### Two philosophies, one goal

Both tools exist to kill manifest duplication. They disagree on *how*:

- **Helm templates.** You write YAML with `{{ }}` placeholders and ship default
  **values**; `helm` renders the template into manifests at install time. The source
  in your repo is *not* valid Kubernetes YAML — it's a program that produces YAML.
  In exchange you get parameterization, a package format, versioning, a repository,
  and lifecycle management (install/upgrade/rollback/history).
- **Kustomize patches.** You keep *real*, valid manifests (a **base**) and describe
  per-environment **differences** as overlays. There is no template language and no
  render-time logic — just merge and transform. In exchange you get transparency
  (everything in the repo is apply-able YAML) and low cognitive load.

Neither is "more correct." They optimize different things: Helm optimizes
**distribution and flexibility**; Kustomize optimizes **clarity and simplicity**.

### What Helm does that Kustomize doesn't

- **Packaging and distribution.** A chart is a versioned artifact you publish to a
  repository or OCI registry and others install by name and version (Module 07.5).
  Kustomize has no package or registry concept — you consume a base by referencing
  its files (usually via Git).
- **Parameterization with logic.** Conditionals, loops, functions, computed values,
  `required`/`default`, schema validation. When a single artifact must flex across
  *many unknown consumers*, templating expresses that cleanly.
- **Lifecycle management.** Releases, revisions, `rollback`, hooks, and `helm test`
  are a release-management layer Kustomize simply doesn't have (it hands a flat
  stream of manifests to `kubectl`/Argo/Flux and stops there).

### What Kustomize does that Helm doesn't (well)

- **Patching manifests you don't own.** Given raw YAML — a vendor's manifests, a
  rendered chart, an upstream example — Kustomize layers changes without forking or
  templatizing it. Doing the same in Helm means wrapping it in a chart.
- **Zero templating cognitive load.** Reviewers read plain YAML, not a template they
  must mentally execute. For a team with a handful of apps, that transparency is
  often worth more than Helm's power.
- **No render step to trust.** What you commit is what applies (after merges). There's
  no `{{ }}` indentation footgun and no "works until a value is empty" surprise.

### When each wins

```text
Reach for HELM when …                     Reach for KUSTOMIZE when …
──────────────────────                    ───────────────────────────
you DISTRIBUTE software to consumers      you own the manifests and just need
you don't control (a product, an OSS      per-environment variants (dev/stg/prod)
chart, an internal golden-path package)

you need parameterization with LOGIC      you want everything in the repo to be
(conditionals, loops, computed values,    plain, valid, apply-able YAML with no
schema validation)                        templating to reason about

you want lifecycle management             you need to patch manifests you DON'T
(releases, rollback, history, hooks,      own (a vendor's YAML, a rendered chart)
helm test)                                without forking them

you're installing third-party software    a small team wants the lowest-ceremony
(ingress-nginx, cert-manager, Argo CD)    path and minimal cognitive load
```

A useful heuristic: **Am I producing a package for others, or configuring manifests
for myself?** Producing → Helm. Configuring → Kustomize.

### Combining them (the pragmatic answer)

You don't have to choose. A common, powerful pattern is **Helm chart as base,
Kustomize overlay for environment differences**:

- The platform team ships the hardened chart (one versioned, tested artifact).
- A consuming team renders it and applies a *tiny* Kustomize overlay for the handful
  of things their environment changes (a label, a namespace, an extra annotation, a
  sidecar) — without forking the chart or drowning in chart values.

Two ways to wire it:

```text
# 1) Render with Helm, then patch the output with Kustomize
helm template app ./chart > base/rendered.yaml
kubectl apply -k overlays/prod        # overlay references rendered.yaml + patches

# 2) Let Kustomize inflate the chart natively (needs the helm plugin)
kustomize build --enable-helm overlays/prod   # kustomization.yaml has a helmCharts: block
```

### How Argo CD sees both

Argo CD (Phase 8) renders both natively: point an Application at a Helm chart (with
values) *or* a Kustomize path, and it produces manifests and reconciles them to the
cluster. It even supports the combination (Helm charts inflated through Kustomize, or
charts with Kustomize post-rendering). So "Helm vs Kustomize" is rarely a platform
mandate — GitOps tooling treats them as interchangeable rendering front-ends, and you
can use the right one per app.

---

## 2. Why it matters for platform engineering

- **You will operate both, forever.** Third-party platform components ship as Helm
  charts; many teams' app config is cleanest as Kustomize overlays. Fluency in both —
  and in combining them — is the actual job, not allegiance to one.
- **The decision is a developer-experience decision.** Handing a five-app team a
  50-value chart when they needed a three-line overlay is a cognitive-load mistake.
  Matching the tool to the consumer *is* platform product thinking.
- **It de-risks the religious war.** Teams burn weeks arguing Helm vs Kustomize. A
  clear framework ("distribute → Helm, configure → Kustomize, and here's how to
  combine them") ends the argument and lets people ship.
- **It sets up GitOps.** Phase 8 drives whichever one you chose. Knowing how Argo
  renders each means your packaging choice and your delivery system fit together.

---

## 3. Mental model

Put them on one axis — **generate vs transform** — and let the job pick the point:

```text
   GENERATE (templating)                               TRANSFORM (patching)
   Helm ◀───────────────────────────────────────────────────────▶ Kustomize

   "I ship a package to consumers        "I own these manifests and need
    I don't control, with logic and       per-environment variants, in plain
    a version number."                     apply-able YAML, no templating."

   COMBINE: Helm renders the base  ──▶  Kustomize patches the environment deltas
            (one versioned artifact)      (a tiny, readable overlay per env)

   Decision test:  Producing a package for others?  → Helm
                   Configuring manifests for myself? → Kustomize
                   Both at once?                      → Chart base + overlay
```

The durable rule: **Helm is a packaging system; Kustomize is a configuration
transformer.** They're complementary layers, not competitors — and Argo CD will run
whichever you pick.

---

## 4. Minimal implementation

Deploy the *same* trivial app two ways and feel the difference in source shape. With
Helm, the source is a template that needs rendering:

```bash
helm template app ./helm-app --set replicaCount=3 | head -n 20   # {{ }} → YAML
```

With Kustomize, the source is already valid YAML; the overlay only states the delta:

```bash
# overlays/prod/kustomization.yaml declares: resources: [../../base], replicas: [{name: web, count: 3}]
kubectl kustomize overlays/prod | head -n 20                     # real YAML in, real YAML out
```

Same running result (three replicas of one app), two philosophies: Helm *produced*
the manifest from a template; Kustomize *transformed* a manifest that already
existed. The lab deploys one app **three** ways — Helm, Kustomize, and Helm+Kustomize
— so you can compare them head to head.

## 5. Hands-on lab

You'll deploy one identical app three ways on kind — Helm only, Kustomize only, and a
Helm-rendered base with a Kustomize overlay — then compare the source shape,
maintainability, and cognitive load of each.

➡️ **[Start the lab: Deploy one app three ways](./lab/README.md)**

## 6. Production considerations

- **Pick per use case, not per religion.** Distributing the golden-path workload →
  Helm chart. A team configuring their own three services → Kustomize overlays.
  Mandating one everywhere creates friction somewhere.
- **Standardize the *combination* pattern if you mix them.** If teams render charts
  and patch with Kustomize, pick one approach (post-render vs `helm template` +
  overlay vs Argo's native support) and document it, so every repo looks the same.
- **Keep secrets out of both.** Neither encrypts anything. Values files and
  `secretGenerator` literals both leak plaintext into Git. Use a real secrets
  solution regardless of tool.
- **Pin versions on both sides.** Pin chart versions *and* the Kustomize/`kubectl`
  version used to render, or "it worked yesterday" returns from either direction.
- **Render in CI and diff.** Whatever the tool, produce the manifests in CI
  (`helm template`, `kustomize build`) and run policy checks and `kubectl diff`
  before applying. Argo CD does this continuously; mirror it in pipelines.

## 7. Common mistakes

- **Treating it as a holy war.** — Teams waste weeks arguing instead of shipping.
  *Fix:* apply the framework (distribute → Helm, configure → Kustomize, combine when
  useful) and move on.
- **Templating everything, even what you own.** — A full chart for a single app you
  control adds a template language you must mentally execute for no distribution
  benefit. *Fix:* if you're not distributing it, a Kustomize overlay is often simpler.
- **Forking a third-party chart to change two fields.** — Now you own a fork and its
  upgrades forever. *Fix:* keep the chart as-is and layer a Kustomize overlay (or use
  chart values / post-render) for the deltas.
- **Re-implementing Helm in Kustomize.** — Piling on patches and generators to fake
  parameterization for many unknown consumers. *Fix:* if you need real logic and
  distribution, that's Helm's job.
- **Assuming you must choose one.** — Picking a single tool org-wide and contorting
  every use case into it. *Fix:* combine them, and let Argo CD render whichever fits.

## 8. Assessment

**Knowledge checks**

1. In one sentence each, what does Helm optimize for and what does Kustomize optimize
   for?
2. Give a concrete job where Helm clearly wins, and one where Kustomize clearly wins.
3. Describe the "Helm base + Kustomize overlay" pattern and a situation where it beats
   either tool alone.
4. How does Argo CD treat Helm and Kustomize, and why does that defuse the "which one"
   debate?
5. Why is "fork the chart to change two fields" an anti-pattern, and what's the fix?

**Concept exercise**

> Explain to a teammate when to template a workload versus when to patch it —
> **without naming Helm or Kustomize.** Frame it around *distributing a package* vs
> *configuring manifests you own*.

**Architecture / trade-off exercise**

> Your platform ships a hardened chart (Module 07.2). A product team needs the same
> workload but with one extra sidecar and a team-specific annotation in prod only.
> Compare three approaches — (a) add sidecar support to the chart's values, (b) fork
> the chart, (c) render the chart and apply a Kustomize overlay — and recommend one.
> What does your choice optimize for, and what does it cost?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Helm optimizes distribution and flexible parameterization (packaging +
  templating + lifecycle); Kustomize optimizes clarity and simplicity (plain YAML +
  overlays, no templating).
- **Q2:** Helm wins for distributing a versioned golden-path chart or installing
  ingress-nginx; Kustomize wins for a team producing dev/stg/prod variants of
  manifests they own, or patching a vendor's raw YAML.
- **Q3:** Helm renders one versioned, tested base; a small Kustomize overlay applies
  the handful of environment deltas. It beats pure Helm when you'd otherwise add many
  niche values, and pure Kustomize when you still want a distributed, versioned base.
- **Q4:** Argo CD renders both natively (and the combination), reconciling the output.
  So packaging choice is per-app, not a platform-wide mandate.
- **Q5:** A fork means owning upstream's maintenance and upgrades forever for a tiny
  change. Fix: keep the chart intact and layer an overlay / use values / post-render.
- **Trade-off:** (a) is best if the sidecar is a *reusable platform capability* (bake
  it into the chart behind a value); (c) is best if it's *team-specific* (keep it in
  the team's overlay, chart stays generic); (b) is almost never right. The choice is
  really "is this a platform concern or a team concern?"

</details>

## 9. Further reading

- Helm — [Documentation home](https://helm.sh/docs/)
- Kustomize — [Official documentation](https://kubectl.docs.kubernetes.io/references/kustomize/)
- Argo CD — [Tool detection: Helm and Kustomize](https://argo-cd.readthedocs.io/en/stable/user-guide/application_sources/)
- Kustomize — [Helm chart inflation generator](https://kubectl.docs.kubernetes.io/references/kustomize/builtins/#_helmchartinflationgenerator_)
- Helm — [Post-rendering](https://helm.sh/docs/topics/advanced/#post-rendering)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 07.3 — Kustomize](../03-kustomize/)
· _Next:_ [Module 07.5 — OCI Artifacts and Distribution →](../05-oci-artifacts-and-distribution/)
