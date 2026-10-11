# Module 15.4 — Backstage Software Templates

> Software Templates (the **scaffolder**) are where self-service provisioning becomes
> real: a developer fills in a short form and gets a new, production-ready repository —
> code skeleton, CI, Helm chart, and `catalog-info.yaml` — created and registered
> automatically. This is the **golden path** from [Module 01.3](../../01-platform-foundations/03-developer-experience/)
> turned into a one-click action, and the end of Project 1's "onboard a service by
> hand."

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 15.3](../03-backstage-software-catalog/), a running Backstage
app, and the [pipeline-templates-as-product](../../06-cicd-for-platform-teams/04-pipeline-templates-as-product/)
ideas from Phase 6. A GitHub account for the publish step (optional).

## Learning objectives

By the end of this module you will be able to:

- Explain how a Software Template realizes a golden path end to end.
- Describe a template's three parts: **metadata**, **parameters**, and **steps**.
- Use the core actions `fetch:template`, `publish:github`, and `catalog:register`.
- Build a **skeleton** whose files are templated with user input.
- Version a template and reason about escape hatches and custom actions.

---

## 1. Concept

### The scaffolder is the "new-service.sh" from Module 01, grown up

Back in [Module 01.1](../../01-platform-foundations/01-what-is-platform-engineering/)
the Thinnest Viable Platform was a `new-service.sh` that stamped out a known-good
starter. The Backstage **scaffolder** is that idea at full strength: a form in the
portal that, on submit, runs a sequence of actions to create and wire up a new
service. It is the IDP's **self-service provisioning** capability (Module 01.4) and the
most direct attack on *setup friction* (Module 01.3). A developer who used to spend two
days copying YAML now spends two minutes filling a form.

### Anatomy of a template

A template is a single `Template` entity (catalogued like anything else) with three
parts:

```text
Template
├── metadata     name, title, description, tags — how it appears in "Create"
├── spec.parameters   the FORM: fields the developer fills in (name, owner, …)
└── spec.steps        the ACTIONS: what runs on submit (fetch, publish, register)
```

- **Metadata** controls how the template shows up in the portal's *Create* page.
- **Parameters** define the form. Each parameter is a typed field (string, enum,
  boolean) rendered by Backstage; they become `${{ parameters.<name> }}` values in the
  steps. You can group parameters into pages and add validation (required fields,
  patterns, entity pickers that read the catalog).
- **Steps** are an ordered list of **actions** executed server-side on submit. Each
  step can consume outputs of earlier steps via `${{ steps.<id>.output.<field> }}`.

### The core actions

Three built-in actions do the bulk of the work; a fourth is common:

- **`fetch:template`** — reads a **skeleton** directory and renders it, substituting
  `${{ values.* }}` placeholders with the developer's parameters. This produces the new
  repo's contents in a workspace.
- **`publish:github`** — creates a GitHub repository and pushes the rendered contents,
  setting default branch, protection, and topics. (Equivalents exist for GitLab,
  Bitbucket, Azure.)
- **`catalog:register`** — registers the new repo's `catalog-info.yaml` into the
  Software Catalog, so the service appears in the inventory **immediately** (Module
  15.3). The service is born catalogued.
- **`github:actions:dispatch`** (optional) — kicks off a workflow in the new repo, e.g.
  to run the first build or request initial infrastructure.

```text
Developer submits the form
        │
        ▼
  fetch:template   render ./skeleton with { name, owner, … }  → workspace
        │
        ▼
  publish:github   create repo + push rendered files          → remoteUrl
        │
        ▼
  catalog:register register catalog-info.yaml from the repo    → catalog entry
        │
        ▼
  (github:actions:dispatch) trigger first CI run               → green build
```

### The skeleton: a templated starter

The **skeleton** is a directory of real files with `${{ values.* }}` placeholders. For a
Go microservice it contains exactly what Project 1 and 2 taught you to want *by
default*:

- `main.go` — a working HTTP service.
- `Dockerfile` — a secure, multi-stage, non-root build (Phase 2).
- `chart/` — a Helm chart with sane defaults (Phase 7).
- `.github/workflows/ci.yaml` — CI that **consumes the platform's reusable workflow**
  (Module 06.4) rather than re-authoring a pipeline.
- `catalog-info.yaml` — so the service is catalogued on creation (Module 15.3).

Because these defaults are baked in, every service created from the template starts
secure, observable, deployable, and catalogued — the golden path, by construction. The
developer never *chooses* non-root or SBOMs; convention supplies them (Module 15.1).

> **Escaping GitHub Actions expressions.** GitHub workflows use `${{ … }}` too, which
> collides with the scaffolder's templating. Mark workflow files
> `copyWithoutTemplating` in `fetch:template` (or escape them) so the new repo keeps its
> literal `${{ github.sha }}` expressions. The lab does this.

### Templates are products: version them

A template with users is an API — the exact lesson of [Module 06.4](../../06-cicd-for-platform-teams/04-pipeline-templates-as-product/).
Reference templates (and the reusable workflow they wire in) at a **specific Git tag**,
not `main`, so a change to the template does not silently alter what new services get.
Ship breaking changes as a new version, keep the old one working with a deprecation
note, and track **adoption** — what percent of new services use the current template
version? That metric reappears, front and centre, in Module 15.6.

### Custom actions and escape hatches

The built-in actions cover most needs, but you can write **custom actions** (a Node
module) to do platform-specific work: open a GitOps PR, create a namespace via your
Namespace Operator (Phase 10), or request a secret via ESO. Custom actions are how the
scaffolder fans a single request across all five planes — the orchestration from Module
15.1, realized. And because golden paths are not cages, a good template offers
**escape-hatch parameters** (e.g. an advanced page to override the base image), kept
default-off and visible.

---

## 2. Why it matters for platform engineering

The scaffolder is where the IDP stops *describing* services and starts *creating* them.
It is the single highest-leverage piece of the developer control plane: one well-made
template means every new service across the org starts on the paved road, with security
and observability wired in, catalogued and deployable from minute one. That is how a
platform makes the Nth team as fast as the first (Module 01.1) and how "golden path"
stops being a slide and becomes a button.

It also unifies the whole course. A single `fetch → publish → register` template pulls
in your Phase 2 Dockerfile, your Phase 6 pipeline template, your Phase 7 chart, and your
Module 15.3 catalog entry — and sets up the custom actions that will drive Phase 5/8
provisioning in Project 4. The template *is* the golden path, and the golden path is the
product.

---

## 3. Mental model

```text
   SOFTWARE TEMPLATE = a FORM (parameters) + a SEQUENCE (steps) over a SKELETON
   ───────────────────────────────────────────────────────────────────────────

   parameters  →  the questions you ask the developer (keep them few: convention!)
   skeleton    →  real files with ${{ values.* }} — your defaults, baked in
   steps       →  fetch:template → publish:github → catalog:register (+ dispatch)
   outputs     →  each step feeds the next (${{ steps.publish.output.remoteUrl }})
   product     →  pin to a TAG, version it, measure adoption, offer escape hatches
   orchestration → custom actions fan the request across the five planes

   One line: ask little, generate a lot — the paved road as a one-click action.
```

One sentence: **a template is a form plus an ordered set of actions that renders your
golden-path skeleton and registers the result — self-service provisioning, realized.**

---

## 4. Minimal implementation

The smallest useful template asks for a name, renders a one-file skeleton, and
publishes it. Here is the shape (the lab builds the full Go version):

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: go-microservice
  title: Go Microservice
  description: Create a production-ready Go service on the golden path
spec:
  owner: team-platform
  type: service
  parameters:
    - title: Service information
      required: [name, owner]
      properties:
        name:
          title: Service name
          type: string
          pattern: "^[a-z][a-z0-9-]*$"
        owner:
          title: Owning team
          type: string
          ui:field: OwnerPicker   # reads Groups from the catalog
  steps:
    - id: fetch
      name: Render the skeleton
      action: fetch:template
      input:
        url: ./skeleton
        copyWithoutTemplating: [".github/workflows/*"]
        values:
          name: "${{ parameters.name }}"
          owner: "${{ parameters.owner }}"
    - id: publish
      name: Create the GitHub repo
      action: publish:github
      input:
        repoUrl: "github.com?owner=your-org&repo=${{ parameters.name }}"
    - id: register
      name: Register in the catalog
      action: catalog:register
      input:
        repoContentsUrl: "${{ steps.publish.output.repoContentsUrl }}"
        catalogInfoPath: /catalog-info.yaml
  output:
    links:
      - title: Open the new repository
        url: "${{ steps.publish.output.remoteUrl }}"
```

Notice how little the developer supplies (a name and a team) versus how much they get
(a whole repo, catalogued). That asymmetry — **ask little, generate a lot** — is the
entire value. The lab fleshes out the skeleton with a real Go service, Dockerfile,
chart, CI, and descriptor.

---

## 5. Hands-on lab

You will build the `go-microservice` golden-path template: a
[`template.yaml`](./lab/template.yaml) with a parameter form and `fetch → publish →
register` steps, and a [`skeleton/`](./lab/skeleton/) containing a working Go service,
a secure Dockerfile, a Helm chart, platform CI, and a `catalog-info.yaml` — all
templated with the developer's input. You will run it from the portal's *Create* page
(the publish step is optional/local-dry-run).

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Pin to tags, not `main`.** Reference the template and the reusable workflow it
  wires in at a specific version, so new services are reproducible and template changes
  are deliberate.
- **Keep parameters minimal.** Every extra field is cognitive load and a chance to pick
  the wrong thing. Supply defaults by convention; ask only for what is service-specific.
- **Make the skeleton the source of truth for defaults.** Security (non-root, signed
  images, SBOM) and observability (OTel wiring) belong in the skeleton so they are
  guaranteed, not optional.
- **Handle partial failure.** If `publish:github` succeeds but `catalog:register`
  fails, the developer has a repo that is invisible to the catalog. Make steps
  idempotent and surface clear errors (Module 15.1).
- **Govern template sprawl.** Ten near-identical templates are as bad as none. Prefer a
  few parameterized golden paths over a template per team.
- **Measure adoption and escape-hatch use.** Track which template version new services
  use and how often advanced overrides are set — both are product-feedback signals.

---

## 7. Common mistakes

- **A template with twenty required fields.** It reproduces the setup friction it was
  meant to remove. *Fix:* convention over configuration; sensible defaults.
- **Referencing `main` instead of a tag.** New services silently change when the
  template does. *Fix:* pin template and reusable-workflow versions.
- **Forgetting `catalog:register`.** Services get created but never appear in the
  catalog, so the inventory is incomplete from day one. *Fix:* always register; verify
  the entry shows up.
- **GitHub Actions expressions eaten by the scaffolder.** `${{ github.sha }}` in the
  skeleton's workflow gets templated away. *Fix:* `copyWithoutTemplating` for workflow
  files.
- **Re-authoring CI in the skeleton.** Pasting a full pipeline instead of consuming the
  platform's reusable workflow. *Fix:* the skeleton's CI should `uses:` the Module 06.4
  template.
- **No escape hatch.** Teams with a legitimate variation fork the template and vanish
  from your metrics. *Fix:* default-off advanced parameters, kept visible.

---

## 8. Assessment

**Knowledge checks**

1. What are the three parts of a `Template`, and what does each control?
2. In order, what do `fetch:template`, `publish:github`, and `catalog:register` do?
3. Why must GitHub Actions `${{ … }}` expressions in the skeleton be copied without
   templating?
4. Why reference a template (and its reusable workflow) at a Git tag rather than
   `main`?
5. What is a custom action for, and how does it relate to the orchestration layer from
   Module 15.1?

**Concept exercise**

> Explain how one-click service creation works **without naming Backstage or the
> scaffolder**. Describe what the developer provides, what gets generated, and why the
> defaults matter more than the form.

**Architecture / trade-off exercise**

> Two teams ask for different "new service" templates: one wants a slim service with no
> database, another wants the same service plus a Postgres and a preview environment.
> Do you build two templates, one template with more parameters, or one template plus
> custom actions? Justify your choice using convention-over-configuration, template
> sprawl, and the five-planes orchestration idea.

<details>
<summary>Discussion</summary>

- **Q1:** Metadata (how it appears in *Create*), parameters (the form the developer
  fills), and steps (the ordered actions run on submit).
- **Q2:** `fetch:template` renders the skeleton with the developer's values;
  `publish:github` creates and pushes the repo; `catalog:register` adds the new
  service's `catalog-info.yaml` to the catalog.
- **Q3:** The scaffolder also uses `${{ … }}`, so without `copyWithoutTemplating` it
  would consume the workflow's GitHub expressions, breaking CI in the new repo.
- **Q4:** Pinning makes new services reproducible and makes template changes a
  deliberate, versioned event (Module 06.4) instead of silently altering every new
  service.
- **Q5:** A custom action runs platform-specific work (open a GitOps PR, create a
  namespace, request a secret). Chaining custom actions is how the scaffolder fans one
  request across the five planes — the orchestration layer, implemented.
- **Trade-off:** Prefer **one parameterized template plus custom actions**: a boolean
  "needs a database" parameter (default off) and a custom action that provisions
  Postgres and a preview env via the resource/delivery planes. Two templates duplicate
  the golden path and drift; a forest of parameters hurts convention — so keep the form
  small and push the variation into optional parameters and orchestration steps.

</details>

---

## 9. Further reading

- Backstage — [Software Templates overview](https://backstage.io/docs/features/software-templates/)
- Backstage — [Writing templates](https://backstage.io/docs/features/software-templates/writing-templates)
- Backstage — [Builtin scaffolder actions](https://backstage.io/docs/features/software-templates/builtin-actions)
- Backstage — [Writing custom actions](https://backstage.io/docs/features/software-templates/writing-custom-actions)
- Backstage — [Input examples and `copyWithoutTemplating`](https://backstage.io/docs/features/software-templates/input-examples)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [15.3 — Backstage Software Catalog](../03-backstage-software-catalog/)
· _Next:_ [15.5 — Backstage Plugins →](../05-backstage-plugins/)
