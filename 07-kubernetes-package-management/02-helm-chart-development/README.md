# Module 07.2 — Helm Chart Development

> Installing other people's charts is table stakes. The platform-engineering skill is
> **authoring** one: a reusable, hardened, self-validating chart that becomes the
> golden-path workload every team consumes. This module builds that chart — named
> templates and helpers, `values.schema.json` validation, lifecycle hooks, a
> `helm test`, and the lint → test → package → push pipeline that ships it.

**Estimated effort:** ~2.5–3 hours (theory + lab)
**You'll need:** [Module 07.1](../01-helm-fundamentals/), `kubectl` + [kind](https://kind.sigs.k8s.io/), and [Helm](https://helm.sh/) installed.

## Learning objectives

By the end of this module you will be able to:

- Factor shared template logic into **named templates** (`_helpers.tpl`) and use
  `include` + `toYaml` + `nindent` correctly.
- Constrain user input with a **`values.schema.json`** so bad values fail fast.
- Use **lifecycle hooks** and a **`helm test`** to run setup and verification as part
  of a release.
- Bake **hardened defaults** (non-root, read-only root FS, dropped capabilities) into
  a chart so every consumer is secure by default.
- Lint, render, test, package, and push a chart — the chart author's CI loop.

---

## 1. Concept

### From "a folder of templates" to a product

A chart that only you can operate is a liability. A chart that *any* team can install
to get a secure, observable, autoscaled service — without reading its internals — is
a **product**. The difference is in the craft: shared helpers so the chart is DRY,
schema validation so misuse fails loudly, tests so it's verifiable, and defaults that
are safe even when the consumer sets nothing. This module is about that craft.

### Named templates and helpers

The same labels, names, and selectors appear in every manifest of a chart. Repeating
them is how a Service's selector drifts from its Deployment's labels and silently
sends traffic nowhere. The fix is **named templates** — reusable snippets defined
once in `templates/_helpers.tpl` and pulled in with `include`:

```text
{{/* Define a reusable "fullname" and a standard label set, once. */}}
{{- define "platform-app.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "platform-app.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}
```

Then every manifest reuses them:

```text
metadata:
  name: {{ include "platform-app.fullname" . }}
  labels:
    {{- include "platform-app.labels" . | nindent 4 }}
```

Two functions you'll pair constantly:

- **`include "name" .`** renders a named template and returns a string (unlike the
  older `template` action, `include` can be piped). The trailing `.` passes the
  current context so the helper can read `.Release`, `.Values`, etc.
- **`toYaml` + `nindent N`** serializes a values sub-tree to YAML and indents every
  line by `N` spaces, so `resources: {{- toYaml .Values.resources | nindent 4 }}`
  drops the user's whole `resources` block in with correct indentation.

### Validating input with `values.schema.json`

Templates fail in ugly ways when a value is the wrong type (`replicaCount: "two"`) or
missing. A **`values.schema.json`** (standard JSON Schema) sits next to `values.yaml`
and Helm validates the merged values against it on every `install`, `upgrade`,
`template`, and `lint`:

```json
{
  "$schema": "https://json-schema.org/draft-07/schema",
  "type": "object",
  "required": ["image"],
  "properties": {
    "replicaCount": { "type": "integer", "minimum": 1 },
    "image": {
      "type": "object",
      "required": ["repository"],
      "properties": { "repository": { "type": "string" } }
    }
  }
}
```

Now `--set replicaCount=two` is rejected *before* anything reaches the cluster, with
a clear message. Schema validation is the difference between a chart that trusts its
users and one that *protects* them — exactly the posture a platform chart needs.

### Hooks: run work at lifecycle points

Sometimes you need an action *around* a release, not just objects *in* it: run a
database migration before the new version starts, or warm a cache after install.
**Hooks** are ordinary manifests annotated with `helm.sh/hook`:

```text
metadata:
  annotations:
    "helm.sh/hook": pre-upgrade
    "helm.sh/hook-weight": "0"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
```

The hook events fire in order: `pre-install`, `post-install`, `pre-upgrade`,
`post-upgrade`, `pre-delete`, `post-delete`, plus `pre-rollback`/`post-rollback`.
Hook *weight* orders multiple hooks; the *delete policy* controls cleanup. Use hooks
sparingly — they run outside the normal reconcile and can wedge a release if they
hang — but a migration Job is their canonical, legitimate use.

### `helm test`: a release that verifies itself

A chart can ship its own smoke test: a Pod template under `templates/tests/`
annotated with `"helm.sh/hook": test`. `helm test <release>` runs it against the
*live* release and reports pass/fail:

```text
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "platform-app.fullname" . }}-test"
  annotations: { "helm.sh/hook": test }
spec:
  restartPolicy: Never
  containers:
    - name: curl
      image: curlimages/curl:8.10.1
      command: ["curl"]
      args: ["-sf", "http://{{ include "platform-app.fullname" . }}:{{ .Values.service.port }}/readyz"]
```

If the Pod exits 0, the test passes. This is how a consumer gains confidence that
"the release is actually serving," not just "the objects were created."

### Testing templates without a cluster: `helm-unittest`

`helm test` needs a running release. To test *rendering logic* fast — "does setting
`autoscaling.enabled=true` produce an HPA?" — use the
[`helm-unittest`](https://github.com/helm-unittest/helm-unittest) plugin. It asserts
on rendered YAML with no cluster, so it belongs in CI as the first gate. Example
assertion: with `autoscaling.enabled: false`, assert the HPA document is *not*
rendered.

### Packaging and distribution

A finished chart is packaged into a versioned tarball and pushed to a registry:

```text
helm lint ./platform-app            # static checks + schema validation
helm template ./platform-app        # render; eyeball or pipe to a policy check
helm unittest ./platform-app        # fast, cluster-free template assertions
helm package ./platform-app         # → platform-app-1.0.0.tgz
helm push platform-app-1.0.0.tgz oci://<registry>/charts   # distribute (Module 07.5)
```

That pipeline — **lint → unit test → package → push** — is the chart author's
equivalent of a library's build-and-publish. Module 07.5 covers the OCI push in
depth.

---

## 2. Why it matters for platform engineering

- **This chart *is* the golden path.** The hardened `platform-app` chart you build
  here is the concrete payload behind "adopt the paved road." A team sets five
  values and gets a secure, observable, autoscaled workload — the exact deliverable
  the IDP phase wraps a self-service UI around.
- **Security becomes a default, not a checklist.** When non-root, read-only root
  filesystem, and dropped capabilities are baked into the chart, every consumer gets
  them for free. You've moved security *left of the developer* entirely.
- **Schema validation is a support-ticket deflector.** A chart that rejects bad input
  with a clear message is a chart your two-person platform team doesn't have to debug
  over Slack.
- **Versioned charts make fleet-wide change tractable.** Fix a default once, bump the
  chart version, and teams upgrade on their own cadence — governed, reviewable, and
  auditable.

---

## 3. Mental model

Think of a chart as a **typed function with a safety harness**:

```text
            values.schema.json
          (the TYPE SIGNATURE: rejects bad input at the door)
                     │  validates
                     ▼
  values.yaml ──▶  TEMPLATES  ──▶  rendered, HARDENED manifests
  (+ user       (_helpers.tpl =        (non-root, RO-rootfs,
   overrides)    shared private         dropped caps, probes,
                 functions)             HPA/PDB/NetworkPolicy)
                     │
     hooks ─────────┤  run work AROUND the release (migrations, etc.)
     tests ─────────┘  verify the LIVE release (helm test)

   Package the whole thing → versioned .tgz → push to a registry → teams install it.
```

The durable rule: **a good chart protects its consumer.** It validates their input,
ships safe defaults they can't forget to set, and can prove it works.

---

## 4. Minimal implementation

Scaffold a chart, then watch schema validation and rendering do their jobs — all
cluster-free:

```bash
helm create platform-app          # a working chart skeleton to edit down
rm -rf platform-app/templates/tests   # we'll write our own

# Add a tiny schema that requires an integer replicaCount
cat > platform-app/values.schema.json <<'EOF'
{
  "$schema": "https://json-schema.org/draft-07/schema",
  "type": "object",
  "properties": { "replicaCount": { "type": "integer", "minimum": 1 } }
}
EOF

# Valid input renders; the schema is happy
helm template demo ./platform-app --set replicaCount=2 >/dev/null && echo "OK: valid"

# Invalid input is rejected BEFORE the cluster is ever touched
helm template demo ./platform-app --set replicaCount=two || echo "Rejected by schema"
```

The second command fails with a schema error, not a broken manifest. You just moved a
whole class of mistakes from "3 a.m. incident" to "instant, local, obvious." The lab
turns this skeleton into a production-grade, hardened chart.

---

## 5. Hands-on lab

You'll build the `platform-app` chart from real starter files: helpers, a strict
schema, hardened security defaults, Deployment/Service/HPA/PDB/ServiceAccount/
NetworkPolicy templates, and a `helm test`. Then you'll lint it, render it, install
it on kind, and run its self-test.

➡️ **[Start the lab: Build the platform-app chart](./lab/README.md)**

## 6. Production considerations

- **Harden by default; let consumers opt *out*, not *in*.** Non-root, read-only root
  filesystem, `allowPrivilegeEscalation: false`, and `drop: [ALL]` should be the
  defaults. A team that genuinely needs a writable path sets one value — but the safe
  path is the default path.
- **Pin the schema strictly, loosen deliberately.** Use `required`, types, and
  `additionalProperties: false` where you can. Every gap in the schema is a way for a
  consumer to produce a broken release you'll be paged about.
- **Keep hooks idempotent and bounded.** A migration hook must be safe to re-run and
  must time out. A hook that hangs blocks the whole release.
- **Template defensively.** Guard optional blocks (`{{- with .Values.resources }}`),
  use `required` for values with no safe default, and never let a missing value
  render an empty-but-valid-looking manifest.
- **Version the chart like an API.** Bump `version` on every change; treat removing a
  value or changing a default as a breaking change with a migration note.
- **Lint and unit-test in CI.** `helm lint`, `helm template | <policy>`, and
  `helm unittest` are fast and catch regressions before a chart ever reaches a
  cluster. Sign and provenance-check published charts (Module 07.5).

## 7. Common mistakes

- **Copy-pasting labels and selectors into every template.** — They drift, and a
  Service stops matching its Pods. *Fix:* define `selectorLabels`/`labels` helpers in
  `_helpers.tpl` and `include` them everywhere.
- **Wrong indentation with `toYaml`.** — `toYaml` with the wrong `nindent` (or
  `indent` vs `nindent`) produces invalid YAML. *Fix:* use `{{- toYaml x | nindent N }}`
  and render with `helm template` to verify.
- **No `values.schema.json`.** — Bad input becomes a cryptic template error or a
  broken object. *Fix:* ship a schema; require what must be set and type everything.
- **Security as an opt-in value.** — `securityContext` defaulting to empty means most
  consumers run privileged. *Fix:* make hardened settings the default; require a
  conscious override to relax them.
- **Hooks that can't be re-run or never finish.** — A non-idempotent or unbounded
  migration hook wedges upgrades. *Fix:* make hooks idempotent, set timeouts, and set
  a sensible `hook-delete-policy`.
- **Skipping `helm test`.** — "The objects exist" is not "the service works." *Fix:*
  ship a test Pod that actually hits a health endpoint of the live release.

## 8. Assessment

**Knowledge checks**

1. Why use `include` + a named template instead of repeating labels in each manifest?
   What does the trailing `.` do?
2. What does `values.schema.json` catch, and at what point in the lifecycle?
3. Name three hardened defaults a platform chart should ship, and the exact fields
   that set them.
4. What's the difference between `helm test` and `helm-unittest`, and where does each
   belong?
5. When would you reach for a hook, and what makes a hook safe?

**Concept exercise**

> Describe how you'd give a hundred teams a secure, autoscaled workload they can adopt
> by setting five values — **without using the words "Helm" or "chart."** Name the
> inputs, the validation, the safe defaults, and the output.

**Architecture / trade-off exercise**

> Your `platform-app` chart defaults to `readOnlyRootFilesystem: true`. A team's app
> writes temp files and now crash-loops on your chart. List the options (relax the
> default for everyone, expose a value, mount an `emptyDir`, reject the app) and argue
> for one. What does your choice say about who owns the security baseline?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** DRY and correctness — one definition of names/labels/selectors keeps the
  Service selector and Deployment labels in lockstep. The trailing `.` passes the
  current render context so the helper can read `.Release`, `.Values`, `.Chart`.
- **Q2:** Type and shape errors in the merged values (wrong type, missing required,
  out-of-range), validated on `install`/`upgrade`/`template`/`lint` — before objects
  reach the cluster.
- **Q3:** e.g. `runAsNonRoot: true` + numeric `runAsUser`; `readOnlyRootFilesystem:
  true`; `allowPrivilegeEscalation: false`; `capabilities.drop: [ALL]`;
  `seccompProfile.type: RuntimeDefault`.
- **Q4:** `helm-unittest` asserts on *rendered templates* with no cluster (fast CI
  gate); `helm test` runs a Pod against a *live release* to prove it serves. Use both.
- **Q5:** For work that must happen around the release (a migration before the new
  version). A safe hook is idempotent, bounded by a timeout, and has a sane delete
  policy.
- **Trade-off:** Best answer is usually expose a value *and* mount a writable
  `emptyDir` at `/tmp` by default, keeping `readOnlyRootFilesystem: true`. Relaxing
  the default for everyone forfeits the baseline; the platform should own the safe
  default and offer a narrow, explicit escape hatch.

</details>

## 9. Further reading

- Helm — [Chart template guide (named templates, functions)](https://helm.sh/docs/chart_template_guide/named_templates/)
- Helm — [Schema files (`values.schema.json`)](https://helm.sh/docs/topics/charts/#schema-files)
- Helm — [Chart hooks](https://helm.sh/docs/topics/charts_hooks/)
- Helm — [Chart tests (`helm test`)](https://helm.sh/docs/topics/chart_tests/)
- [helm-unittest plugin](https://github.com/helm-unittest/helm-unittest)
- Kubernetes — [Configure a Security Context for a Pod or Container](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 07.1 — Helm Fundamentals](../01-helm-fundamentals/)
· _Next:_ [Module 07.3 — Kustomize →](../03-kustomize/)
