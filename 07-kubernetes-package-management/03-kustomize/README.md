# Module 07.3 — Kustomize

> Kustomize takes the opposite bet from Helm: instead of *generating* YAML from
> templates, it starts with plain, valid Kubernetes manifests (a **base**) and
> **patches** them per environment (**overlays**) — no template language, no `{{ }}`.
> This module teaches bases, overlays, patches, generators, and transformers, and
> builds the `dev`/`prod` overlay pattern you'll use constantly in GitOps.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 07.1](../01-helm-fundamentals/), `kubectl` + [kind](https://kind.sigs.k8s.io/) (Kustomize is built into `kubectl`).

## Learning objectives

By the end of this module you will be able to:

- Explain the **base + overlay** model and how it differs from templating.
- Apply **strategic-merge** and **JSON (RFC 6902)** patches, and know when to use each.
- Generate config with **`configMapGenerator`**/**`secretGenerator`** and get free
  rollouts from content hashes.
- Use **transformers** (images, namespace, common labels) to rewrite a base safely.
- Build and apply overlays with `kustomize build` and `kubectl apply -k`.

---

## 1. Concept

### A different answer to the same problem

Module 07.1 framed the core problem: one workload, many environments, and no
single source of truth if you copy manifests. Helm solves it by **templating** —
parameterize the YAML and render it with values. Kustomize solves it by
**composition and patching** — keep one set of *real* manifests and describe the
*differences* for each environment as overlays. No new language, no rendering step:
what you check in is valid Kubernetes YAML that `kubectl` already understands.

### Resources, bases, and overlays

Three nouns:

- **Resource** — an ordinary Kubernetes manifest (a Deployment, a Service). Nothing
  Kustomize-specific; it's valid YAML you could `kubectl apply` directly.
- **Base** — a directory with a `kustomization.yaml` that lists `resources`. It's the
  environment-agnostic definition — the common truth every environment shares.
- **Overlay** — a directory whose `kustomization.yaml` references the base (and adds
  patches, extra resources, name prefixes, etc.). One overlay per environment.

```text
base/                     # the shared, valid manifests
├── kustomization.yaml    #   resources: [deployment.yaml, service.yaml]
├── deployment.yaml
└── service.yaml

overlays/
├── dev/                  # base + "dev is small and verbose"
│   ├── kustomization.yaml
│   └── replicas-patch.yaml
└── prod/                 # base + "prod is bigger and adds an HPA"
    ├── kustomization.yaml
    ├── replicas-patch.yaml
    └── hpa.yaml
```

The overlay *includes* the base and layers changes on top. You never copy the base;
you reference it. Fix a container port in the base and every overlay inherits the fix.

### Patches: strategic-merge vs JSON

Overlays change the base through **patches**. Two flavors:

- **Strategic-merge patch** — a partial manifest that is *merged* into the base by
  Kubernetes' field-aware merge rules. You write just the fields you want to change,
  in the natural shape of the object. Kubernetes knows that `containers` is a list
  keyed by `name`, so it merges by name rather than replacing the whole list:

```text
# overlays/prod/replicas-patch.yaml — only the deltas
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
```

- **JSON patch (RFC 6902)** — a precise, operation-based edit (`add`, `replace`,
  `remove`) against a path. Reach for it when a merge is ambiguous or you must target
  one list element exactly:

```text
# overlays/prod/kustomization.yaml (excerpt)
patches:
  - target: { kind: Deployment, name: web }
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/image
        value: registry.example.com/web:1.4.2
```

Rule of thumb: **strategic-merge for the common case** (it reads like the object);
**JSON patch for surgical precision** (a specific array index, a remove).

### Generators: config and secrets with built-in rollouts

`configMapGenerator` and `secretGenerator` build ConfigMaps/Secrets from literals or
files — and, crucially, append a **content hash** to the name
(`app-config-7f9c2b`). When the content changes, the name changes, so any Deployment
referencing it is *forced to roll* (new pod template), fixing the classic bug where
editing a ConfigMap leaves pods running the old values:

```text
configMapGenerator:
  - name: app-config
    literals:
      - LOG_LEVEL=info
```

### Transformers: rewrite the whole set at once

Transformers apply a change across *all* resources an overlay produces:

- **`images`** — override image name/tag/digest without editing the Deployment:
  `images: [{ name: web, newTag: 1.4.2 }]`.
- **`namespace`** — drop every resource into a target namespace.
- **`namePrefix`/`nameSuffix`** — e.g. prefix `prod-` to every object name.
- **`commonLabels`/`labels`** and **`commonAnnotations`** — stamp labels/annotations
  onto everything (and, for `commonLabels`, into selectors too).
- **`replicas`** — set replica counts by resource name.

Transformers are why an overlay can retarget an entire app to a namespace, retag its
image, and label everything — in a few declarative lines, no patch files.

### Running it: `kustomize build` and `kubectl apply -k`

Kustomize renders by *building* an overlay into a flat stream of manifests:

```text
kustomize build overlays/prod            # print the final YAML
kubectl apply -k overlays/prod           # build AND apply (kustomize is built into kubectl)
kubectl kustomize overlays/prod          # same build, via kubectl, no apply
```

Because the output is just manifests, you can pipe `kustomize build` into a policy
check, a diff, or `kubectl apply` — it composes with everything that speaks YAML.

> `kubectl` bundles its *own* copy of Kustomize, which can lag the standalone
> `kustomize` binary. For newer fields, install and use the standalone CLI and treat
> `kubectl -k` as the convenience path.

---

## 2. Why it matters for platform engineering

- **It's the native GitOps format.** Argo CD and Flux both render Kustomize overlays
  directly. "Promote dev → prod" becomes a small, readable overlay diff in a pull
  request — exactly the change unit GitOps (Phase 8) wants.
- **No templating means low cognitive load.** Everything in the repo is real YAML a
  reviewer can read without mentally executing a template. For teams that own a
  *handful* of apps, that clarity is often worth more than Helm's power.
- **Safe fleet-wide edits.** A platform team can patch a base (add a security context,
  a label, a sidecar) and every overlay inherits it — without forking manifests.
- **It pairs with Helm.** You can render a third-party Helm chart and then Kustomize
  the output to enforce your standards (Module 07.4) — overlays as a post-processor.

---

## 3. Mental model

Think **inheritance by patching**: a base class and per-environment subclasses that
override only what differs.

```text
                         ┌───────────────────────────┐
                         │          BASE             │
                         │  deployment.yaml (valid)  │
                         │  service.yaml    (valid)  │
                         └─────────────┬─────────────┘
                   references          │          references
            ┌───────────────────────┐ │ ┌───────────────────────┐
            │     overlay: dev      │ │ │     overlay: prod     │
            │  + replicas = 1       │◀┘ └▶ + replicas = 3        │
            │  + image tag :dev     │     + image tag :1.4.2     │
            │                       │     + adds hpa.yaml        │
            └───────────┬───────────┘     └───────────┬──────────┘
                        ▼                              ▼
             kustomize build dev           kustomize build prod
             → flat, valid manifests       → flat, valid manifests
                        │                              │
                        └──────── kubectl apply -k ────┘

   No templates. The repo always holds real YAML; overlays describe the DIFFERENCES.
```

The durable rule: **Helm renders; Kustomize patches.** Kustomize never invents a
value — it only transforms manifests that already exist.

---

## 4. Minimal implementation

Create one real manifest as a base, then an overlay that changes just the replica
count — no templating anywhere:

```bash
mkdir -p base overlays/dev

cat > base/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: { name: web }
spec:
  replicas: 2
  selector: { matchLabels: { app: web } }
  template:
    metadata: { labels: { app: web } }
    spec:
      containers:
        - name: web
          image: nginx:1.27
EOF

cat > base/kustomization.yaml <<'EOF'
resources:
  - deployment.yaml
EOF

# The overlay references the base and patches ONLY the delta
cat > overlays/dev/kustomization.yaml <<'EOF'
resources:
  - ../../base
replicas:
  - name: web
    count: 1
images:
  - name: nginx
    newTag: "1.27-alpine"
EOF

kustomize build overlays/dev    # base, with replicas=1 and the image retagged
```

The base is untouched, valid YAML. The overlay declared *differences* (one replica,
a different tag) and Kustomize produced the combined result. That's the whole idea.

---

## 5. Hands-on lab

You'll build a base plus `dev` and `prod` overlays: `dev` patches the image tag and
runs a single replica; `prod` scales to three, stamps labels, retargets a namespace,
and adds an HPA — then apply both to kind with `kubectl apply -k`.

➡️ **[Start the lab: Base and overlays with Kustomize](./lab/README.md)**

## 6. Production considerations

- **Keep the base environment-agnostic.** No namespaces, no environment-specific
  images or replica counts in the base. If it differs per environment, it belongs in
  an overlay. A leaky base forces copy-paste later.
- **Prefer generators for config, and keep the hash behavior.** Letting
  `configMapGenerator` append content hashes is a feature, not noise — it guarantees
  rollouts on config change. Disabling it (`disableNameSuffixHash`) silently
  reintroduces the stale-config bug.
- **Pin the Kustomize version in CI.** `kubectl`'s built-in Kustomize and the
  standalone binary can render differently. Pin one version so builds are
  reproducible, and render in CI rather than relying on `kubectl -k` locally.
- **Don't put real secrets in `secretGenerator` literals.** They land in Git in plain
  text (base64 is not encryption). Use SOPS, Sealed Secrets, or External Secrets and
  generate only references.
- **Review the built output, not just the overlay.** `kustomize build | kubectl diff`
  shows what will actually change. Patches can interact in surprising ways; diff the
  result.
- **Mind patch brittleness.** JSON patches target paths and indexes; a base change can
  invalidate them. Keep patches minimal and prefer strategic-merge where possible.

## 7. Common mistakes

- **Environment specifics leaking into the base.** — A namespace or `:prod` image in
  the base defeats the whole model. *Fix:* base holds only the shared truth; put all
  differences in overlays.
- **Editing a ConfigMap in place and expecting a rollout.** — Pods keep the old values
  because nothing in the pod template changed. *Fix:* use `configMapGenerator` so the
  name hash changes and forces a new rollout.
- **Reaching for JSON patches by default.** — Index-based paths are brittle and hard to
  read. *Fix:* use strategic-merge for the common case; reserve JSON patch for precise
  list surgery or `remove`.
- **Assuming `kubectl -k` == latest Kustomize.** — The embedded version lags, so a
  field that works in the standalone CLI errors under `kubectl`. *Fix:* install the
  standalone `kustomize`, pin it, and build with it in CI.
- **Secrets in overlays, in plaintext.** — base64 literals in Git are not secret.
  *Fix:* keep secret material out of the repo; integrate a real secrets solution.
- **Overlapping, order-dependent patches.** — Multiple patches touching the same field
  produce confusing results. *Fix:* keep patches small and single-purpose; diff the
  build.

## 8. Assessment

**Knowledge checks**

1. In one sentence, how does Kustomize's approach differ from Helm's?
2. What does `configMapGenerator`'s name-hash behavior fix, and what breaks if you
   disable it?
3. When would you choose a JSON patch over a strategic-merge patch?
4. What belongs in a base, and what belongs in an overlay?
5. Why can `kubectl apply -k` and the standalone `kustomize build` produce different
   output?

**Concept exercise**

> Explain how you'd ship one app to `dev` and `prod` that differ only in replica count
> and image tag — **without using the words "template," "values," or "Helm."**
> Describe the shared definition, the per-environment differences, and how they
> combine.

**Trade-off / debugging exercise**

> A team edited a ConfigMap referenced by their Deployment and bumped the image, then
> ran `kubectl apply -k overlays/prod`. The new image rolled out but the app still
> logs at the old level. Explain why the config change didn't take effect and how
> Kustomize is designed to prevent exactly this.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Helm *generates* manifests from a template language + values; Kustomize
  starts from real manifests and *patches/transforms* them — no templating.
- **Q2:** The name hash forces a rollout when config content changes; disabling it
  (`disableNameSuffixHash`) means editing a ConfigMap leaves pods on stale values.
- **Q3:** When you must target a specific list element by index or `remove` a field —
  precision a field-aware merge can't express cleanly.
- **Q4:** Base: the environment-agnostic shared manifests. Overlay: everything that
  differs per environment (replicas, image tag, namespace, extra resources, labels).
- **Q5:** `kubectl` embeds its own (often older) Kustomize; a newer standalone binary
  supports fields/behaviors the embedded one doesn't, so builds can diverge.
- **Debugging:** The Deployment referenced the ConfigMap by a fixed name, and editing
  its data didn't change the pod template, so no rollout happened. A
  `configMapGenerator` appends a content hash to the name, so changed content yields a
  new name and an automatic rollout.

</details>

## 9. Further reading

- Kustomize — [Official documentation](https://kubectl.docs.kubernetes.io/references/kustomize/)
- Kubernetes — [Declarative management with Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)
- Kustomize — [kustomization.yaml field reference](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/)
- IETF — [RFC 6902: JavaScript Object Notation (JSON) Patch](https://datatracker.ietf.org/doc/html/rfc6902)
- Kubernetes SIG CLI — [Kustomize GitHub repository](https://github.com/kubernetes-sigs/kustomize)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 07.2 — Helm Chart Development](../02-helm-chart-development/)
· _Next:_ [Module 07.4 — Helm vs Kustomize →](../04-helm-vs-kustomize/)
