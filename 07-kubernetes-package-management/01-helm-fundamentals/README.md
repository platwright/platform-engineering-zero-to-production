# Module 07.1 — Helm Fundamentals

> Helm is the package manager for Kubernetes: it turns a pile of templated YAML plus
> a set of values into a **release** you can install, upgrade, roll back, and
> uninstall as one unit. This module teaches the parts — charts, values, releases,
> repositories — and the lifecycle commands, so Helm stops feeling like "magic that
> generates YAML" and starts feeling like `apt`/`npm` for your cluster.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** [Phase 3 · Kubernetes Fundamentals](../../03-kubernetes-fundamentals/), a working `kubectl` + [kind](https://kind.sigs.k8s.io/), and [Helm](https://helm.sh/) installed.

## Learning objectives

By the end of this module you will be able to:

- Explain the duplication problem Helm solves and define **chart**, **release**, and
  **repository** precisely.
- Read a chart's structure — `Chart.yaml`, `values.yaml`, `templates/` — and name
  the core template functions (`default`, `required`, `toYaml`, `include`).
- Run the full lifecycle: `helm install`, `upgrade`, `rollback`, `uninstall`.
- Inspect **release history** and reason about versioning and revisions.
- Trace how the **values hierarchy** (defaults → env file → `--set`) resolves to the
  final rendered manifests.

---

## 1. Concept

### The problem: manifests don't scale by copy-paste

A single service needs a Deployment, a Service, probably an HPA, a
PodDisruptionBudget, a ServiceAccount, and a NetworkPolicy. That's six manifests.
Now ship that service to `dev`, `staging`, and `prod`, where only the image tag, the
replica count, and the resource limits differ. The naive answer is three copies of
six files — eighteen manifests — that are 90% identical and drift the instant someone
edits one and forgets the others.

Multiply by *every* team's *every* service and you have the core failure mode of
hand-rolled Kubernetes: **duplication with no single source of truth**. What you
actually want is *one* definition with a few knobs:

```text
one template  +  "dev" values   → dev manifests
              +  "prod" values  → prod manifests
```

That is exactly what Helm provides, plus the lifecycle machinery to install and
update the result as one tracked unit.

### Charts, values, releases, repositories

Four nouns carry the whole model:

- **Chart** — a package: a directory (or a `.tgz`) of **templates** plus **default
  values** plus metadata. It is the *definition*, like a class or a Debian package.
  It is inert until you install it.
- **Values** — the configuration you feed a chart. The chart ships sensible defaults
  in `values.yaml`; you override what you need per environment.
- **Release** — an *installed instance* of a chart with a specific set of values and
  a name, living in a namespace. Install the same chart twice with different names
  and you get two independent releases. A release has a **revision** number that
  increments on every change.
- **Repository** — an index of packaged charts you can pull from, served over HTTPS
  (a classic Helm repo) or an **OCI registry** (Module 07.5). `helm repo add` wires
  one up the way `apt` adds a source.

> The relationship to remember: a **chart** is a class, **values** are the
> constructor arguments, and a **release** is the object you actually instantiated.
>
> Install the chart three times with three names and you have three releases from
> one class.

### Chart structure

A chart is just a directory with conventions:

```text
platform-app/
├── Chart.yaml          # name, version, appVersion, dependencies — the metadata
├── values.yaml         # DEFAULT values (every key the templates can read)
├── values.schema.json  # optional JSON Schema that validates user-supplied values
├── templates/          # the templated manifests
│   ├── _helpers.tpl    # reusable named templates (helpers), not rendered directly
│   ├── deployment.yaml
│   ├── service.yaml
│   └── NOTES.txt       # post-install message printed to the user
└── charts/             # vendored sub-charts (dependencies), if any
```

Two version fields in `Chart.yaml` trip people up:

- **`version`** — the version of the *chart* (the package). Bump it whenever the
  templates change.
- **`appVersion`** — the version of the *application* the chart deploys (e.g. the
  default image tag). Informational; bump it when the app changes.

### Templates and the functions you'll actually use

Templates are YAML with [Go template](https://pkg.go.dev/text/template) directives in
`{{ }}`, extended by the [Sprig](https://masterminds.github.io/sprig/) function
library. Four functions do most of the work:

- **`.Values.foo`** — read a value. `.Chart`, `.Release`, and `.Capabilities` expose
  chart metadata, release info (name, namespace, revision), and cluster facts.
- **`default`** — supply a fallback: `{{ .Values.replicas | default 2 }}`.
- **`required`** — fail the render with a message if a value is missing:
  `{{ required "image.repository is required" .Values.image.repository }}`. This is
  how a chart refuses to produce a broken manifest.
- **`toYaml`** — serialize a values sub-tree back into YAML (for `resources`,
  `nodeSelector`, etc.), almost always paired with `nindent` for correct indentation.
- **`include`** — render a **named template** (defined in `_helpers.tpl` with
  `define`) and capture its output, so shared snippets like labels live in one place.

### The lifecycle

Helm manages a release through four verbs, and remembers every step:

- **`helm install <name> <chart>`** — render templates with the merged values, then
  create the objects. Records **revision 1**.
- **`helm upgrade <name> <chart>`** — re-render with new values/chart and apply the
  diff. Records **revision 2, 3, …**.
- **`helm rollback <name> <revision>`** — re-apply a *previous* revision's rendered
  manifests. (Rollback itself creates a *new* revision.)
- **`helm uninstall <name>`** — delete the release's objects and its history.

Helm stores each revision's rendered manifest in a **Secret** in the release's
namespace (named `sh.helm.release.v1.<name>.v<n>`). That's why `helm history` and
`helm rollback` work with no server-side component — the state lives in the cluster,
in the open, owned by you. (Helm 2's cluster-side "Tiller" is gone; Helm 3 is a
client that talks straight to the Kubernetes API.)

### The values hierarchy

Final values are *merged*, last-wins, in this order:

```text
chart's values.yaml   (defaults shipped by the chart author)
   └─ overridden by  -f my-values.yaml   (your file, e.g. per environment)
        └─ overridden by  -f more.yaml    (later -f files win over earlier ones)
             └─ overridden by  --set key=value   (highest precedence)
```

So a chart ships safe defaults, each environment supplies a values file, and a
one-off `--set image.tag=abc123` pins a specific build in CI. Understanding this
ordering is how you reason about "where did this field's value actually come from?"

---

## 2. Why it matters for platform engineering

- **A chart is how you distribute the golden path.** The hardened workload template
  your platform team maintains ships as a chart. "Adopt the paved road" becomes
  `helm install`, not "clone and edit nine files." One chart, consumed by everyone.
- **Upgrades become a product capability.** When you fix a security default, you cut
  a new chart version and teams upgrade — a versioned, reviewable change, not a
  manual sweep across forty repos.
- **Rollback is a safety net you get for free.** Because Helm keeps rendered
  revisions, a bad release is one `helm rollback` away. That changes the risk profile
  of shipping.
- **Third-party software arrives as charts.** ingress-nginx, cert-manager,
  Prometheus, ArgoCD — the ecosystem you install to *build* the platform is almost
  all Helm charts. Operating them competently is table stakes.

---

## 3. Mental model

Hold this picture: a chart + values is a **function**, and a release is its **return
value**, versioned every time you call it.

```text
          VALUES (merged, last-wins)
   defaults ─▶ -f env.yaml ─▶ --set ...
                    │
                    ▼
   CHART ─────▶ [ render templates ] ─────▶ rendered Kubernetes manifests
 (templates +        (Go template +                     │
  defaults)           Sprig funcs)                       ▼
                                             ┌───────────────────────────┐
                                             │  RELEASE  "web"           │
                                             │  rev 1 → rev 2 → rev 3 …  │
                                             │  (each stored as a Secret)│
                                             └───────────────────────────┘
        install = create rev 1   upgrade = new rev   rollback = re-apply an old rev
```

The durable rule: **charts are classes, releases are instances, revisions are
history.** Everything `helm` does is instantiate, re-instantiate, or rewind.

---

## 4. Minimal implementation

First, feel the problem Helm solves — do the simplest possible "templating" by hand.
Imagine a manifest where only the image tag changes per environment:

```bash
cat > deploy.tmpl.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: { name: web }
spec:
  replicas: ${REPLICAS}
  selector: { matchLabels: { app: web } }
  template:
    metadata: { labels: { app: web } }
    spec:
      containers:
        - name: app
          image: nginx:${TAG}
EOF

REPLICAS=1 TAG=1.25 envsubst < deploy.tmpl.yaml | kubectl apply -f -
```

That works for one variable, but it has no defaults, no validation, no packaging, no
history, and no rollback. The moment you need "fail if `TAG` is unset" or "roll this
back," you are reinventing Helm badly. So use Helm:

```bash
# Scaffold a working chart to read and learn from
helm create demo

# Render templates locally WITHOUT touching a cluster — your fastest feedback loop
helm template demo ./demo | head -n 40

# Install it as a release named "web" (records revision 1)
helm install web ./demo

# Change a value and upgrade (records revision 2)
helm upgrade web ./demo --set replicaCount=3

# See the history, then rewind to revision 1
helm history web
helm rollback web 1

# Remove everything the release created
helm uninstall web
```

`helm template` renders without a cluster (great for CI and review); `helm install`
renders *and* applies. Same engine, and every `install`/`upgrade`/`rollback` is a
tracked revision you can inspect and reverse.

---

## 5. Hands-on lab

You'll add a real chart repository, install a chart as a release on kind, upgrade it
with an environment values file, read its revision history, and roll it back — the
exact loop you'll run against production charts like ingress-nginx.

➡️ **[Start the lab: Install, upgrade, and roll back a release](./lab/README.md)**

---

## 6. Production considerations

- **Pin chart versions.** Always install with `--version`. An unpinned
  `helm install` grabs "latest," so the same command produces different results next
  week. Pin the chart version the way you pin a container digest.
- **Values belong in Git, not in your shell history.** Keep `values-<env>.yaml` under
  version control and review changes. Reserve `--set` for ephemeral CI inputs like
  the image tag of the build under test.
- **Never put secrets in plain values.** `helm get values` and the release Secret
  expose them. Use a secrets manager, External Secrets, or SOPS — not `values.yaml`.
- **Make upgrades atomic.** `helm upgrade --atomic --wait --timeout 5m` rolls back
  automatically if the release doesn't become healthy, so a bad deploy self-heals
  instead of leaving you half-upgraded.
- **Mind release-history growth.** Helm keeps every revision as a Secret. Cap it with
  `--history-max` (CLI) so long-lived releases don't accumulate thousands of Secrets.
- **CRDs are special.** Helm installs CRDs from `crds/` but does **not** upgrade or
  delete them. Plan CRD upgrades explicitly; a careless chart uninstall can orphan or
  destroy cluster-wide types.
- **Diff before you upgrade.** The `helm diff upgrade` plugin shows exactly what will
  change — treat it like `terraform plan` for releases.

---

## 7. Common mistakes

- **Confusing `version` and `appVersion`.** — Bumping the app image but leaving the
  chart `version` unchanged means consumers can't tell a new package exists. *Fix:*
  bump `version` on every chart change; use `appVersion` for the app's own version.
- **Treating `helm install` as idempotent.** — Running `install` again on an existing
  release errors with "cannot re-use a name." *Fix:* use `helm upgrade --install`
  (a.k.a. `helm upgrade -i`) so first run installs and later runs upgrade.
- **Editing released objects with `kubectl`.** — Hand-editing a Deployment Helm owns
  makes the live state diverge from the release; the next `helm upgrade` silently
  reverts you. *Fix:* change values and upgrade; let Helm own what Helm created.
- **Unpinned chart versions.** — "It worked yesterday" breaks when upstream ships a
  new chart. *Fix:* always `--version`, and record it in Git.
- **Secrets in `values.yaml`.** — They leak through `helm get values` and the release
  Secret. *Fix:* reference an external secret store; never template plaintext secrets.
- **Forgetting `helm uninstall` leaves PVCs and CRDs.** — Data volumes and custom
  resource definitions can survive an uninstall. *Fix:* check for and clean up PVCs
  and CRDs deliberately when you really mean to delete.

---

## 8. Assessment

**Knowledge checks**

1. Define chart, release, and repository, and give the one-line analogy that relates
   them.
2. A teammate runs `helm install api ./chart` twice and the second run errors. What
   happened, and what single flag fixes the workflow?
3. Where does Helm store a release's revision history, and why does that matter for
   `rollback`?
4. Given `values.yaml` sets `replicas: 2`, a `-f prod.yaml` sets `replicas: 3`, and
   the command adds `--set replicas=5`, what is the final value and why?
5. What's the difference between `Chart.yaml`'s `version` and `appVersion`?

**Concept exercise**

> Explain how you'd ship *one* workload definition to three environments that differ
> only in image tag and replica count — **without using the words "Helm," "chart," or
> "template."** Describe the inputs, the thing that combines them, and the output.

**Trade-off / debugging exercise**

> A service was installed with `helm install`, then someone ran
> `kubectl edit deployment` to bump replicas during an incident. A week later a
> routine `helm upgrade` quietly reset replicas back down and caused a brown-out.
> Explain exactly why, and describe the correct way to have made that change
> permanent.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** A chart is the package/definition (class), a release is an installed
  instance of it (object) with values (constructor args), and a repository is the
  index you pull charts from (like an apt source).
- **Q2:** `helm install` is not idempotent — a release with that name already exists.
  Use `helm upgrade --install api ./chart` so the first run installs and subsequent
  runs upgrade the same release.
- **Q3:** In the release's namespace as Secrets (`sh.helm.release.v1.<name>.v<n>`),
  each holding a revision's rendered manifest. `rollback` just re-applies a stored
  revision — no external state needed.
- **Q4:** `5`. Values merge last-wins: defaults (`2`) are overridden by `-f prod.yaml`
  (`3`), and `--set` has the highest precedence (`5`).
- **Q5:** `version` is the chart/package version (bump on template changes);
  `appVersion` tracks the deployed application's version (informational).
- **Debugging:** Helm's desired state still said `replicas: 2`, so `upgrade`
  re-rendered that and overwrote the manual edit. The fix was to change the value in
  the release (`helm upgrade --set replicaCount=…` or the env values file), so Helm's
  source of truth matches the intent.

</details>

---

## 9. Further reading

- Helm — [Introduction and core concepts](https://helm.sh/docs/intro/using_helm/)
- Helm — [Charts guide](https://helm.sh/docs/topics/charts/)
- Helm — [Values and the built-in objects](https://helm.sh/docs/chart_template_guide/values_files/)
- Helm — [Helm commands reference (`helm install`, `upgrade`, `rollback`)](https://helm.sh/docs/helm/helm/)
- CNCF — [Helm project](https://www.cncf.io/projects/helm/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Phase 5 · CI/CD for Platform Teams](../../06-cicd-for-platform-teams/)
· _Next:_ [Module 07.2 — Helm Chart Development →](../02-helm-chart-development/)
