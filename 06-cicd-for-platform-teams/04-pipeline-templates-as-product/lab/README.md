# Lab — Build a golden-path pipeline template teams consume

> You'll build the platform's `app-ci` template as a reusable workflow — complete with
> a typed, default-off **escape hatch** and an **adoption-telemetry** step — then write
> the three-line consumer an application team would maintain. You'll validate both with
> `actionlint` and design how you'd measure adoption and enforce the template for
> production. Fully local and free.

**Estimated time:** ~45–60 minutes
**Type:** build / design
**Deliverable:** A validated [`app-ci.yml`](./app-ci.yml) template, a
[`caller-app-repo.yml`](./caller-app-repo.yml) consumer, and a short written
adoption/enforcement plan.

## Objectives

- Build a reusable workflow that behaves like a product (inputs, output, telemetry).
- Add a visible, auditable escape hatch that is off by default.
- Write the minimal consumer workflow an app team maintains.
- Design an adoption metric and a production-enforcement mechanism.

## Prerequisites

- The lesson [`../README.md`](../README.md) and
  [Module 06.3](../../03-reusable-workflows-and-actions/).
- Everything from
  [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md).
- [`actionlint`](https://github.com/rhysd/actionlint) installed.
- No GitHub account or cloud is required for the core lab.

## Steps

1. **Read the template.**

   Open [`app-ci.yml`](./app-ci.yml). Identify the four product-shaped features: typed
   `inputs` with defaults, an `outputs.tag` consumers can read, the **escape hatch**
   (`skip-integration-tests`, default `false`), and the **telemetry** lines
   (`::notice::` for adoption, `::warning::` when the hatch is used).

2. **Validate it.**

   ```bash
   actionlint app-ci.yml
   ```

   Expect exit 0. Trace how the integration-tests step runs *unless* the hatch is set
   (`if: ${{ !inputs.skip-integration-tests }}`), and how a separate step logs the
   override when it is.

3. **Read and validate the consumer.**

   Open [`caller-app-repo.yml`](./caller-app-repo.yml) — the entire CI an app team
   maintains. Note it pins the moving major tag `@v2` (teams get non-breaking fixes
   automatically) and does *not* set the escape hatch, so the safe default applies.

   ```bash
   actionlint caller-app-repo.yml
   ```

4. **Exercise the escape hatch (edit + reason).**

   In a scratch copy of the consumer, add `skip-integration-tests: true` under `with:`.
   Re-read the template: which step now runs, and what does it log? Write one sentence on
   why a hatch that *logs and counts* is safer than teams silently forking the template.
   Revert.

5. **Design adoption + enforcement (written deliverable).**

   In a few bullet points, answer:

   - **Adoption metric:** how would you compute "% of production services on the golden
     path"? (Hint: count repos whose workflows `uses:` the template, or count prod images
     carrying the platform's signature — Module 06.5.)
   - **Enforcement:** pick one mechanism (required workflow / required status check /
     admit-only-signed-images at the prod gate) and justify why it enforces the *outcome*
     rather than the keystrokes.
   - **Migration:** you need to ship a breaking `v3`. List the four steps you'd take so
     your 50 consumers aren't broken.

## Expected result

- `actionlint app-ci.yml` and `actionlint caller-app-repo.yml` both exit 0.
- You can point to the escape hatch and telemetry lines and explain each.
- A short, concrete adoption + enforcement + migration plan.

## Cleanup

> The core lab creates only local files — nothing to tear down. Remove any scratch
> repo if you ran the optional Step 6 variant from Module 06.3.

```bash
# Nothing to clean up for the local lab. If you pushed to a scratch repo, remove it:
# gh repo delete <your-scratch-repo> --yes
```

## Reflection

- Your template adds a mandatory SBOM step in `v2.4`. Because it's non-breaking, every
  consumer on `@v2` gets it automatically. What did you have to do, and what would be
  different if it were a *breaking* change?
- An escape hatch is used by 30% of teams. Is that a failure of discipline or a signal
  about your defaults? What do you do?
- Enforcing "only platform-signed images reach prod" means a hand-rolled pipeline simply
  can't deploy. Why is that less of a gatekeeper than requiring a specific YAML shape?

## Stretch goals (optional)

- Add a `boolean` input `push` and gate the (future) push step so the same template
  serves PR validation (`push: false`) and merge builds (`push: true`).
- Add a `v1`-style deprecation: a step that prints a `::warning::` with a migration link
  and a sunset date, to model how you'd retire an old major version.
- Sketch a `.github/workflows` "required workflow" org ruleset (in prose) that would
  mandate this template on every repo matching `service-*`.
