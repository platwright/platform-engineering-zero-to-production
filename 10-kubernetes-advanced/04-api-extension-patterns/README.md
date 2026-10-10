# Module 10.4 — Kubernetes API Extension Patterns

> A CRD gives you a new type; this module makes that type behave like a **first-class
> citizen** of the API. You'll add `/status` and `/scale` subresources (so `kubectl
> scale` and HPAs work on your resource), field selectors and printer columns (so it's
> queryable), and use **Server-Side Apply** so your operator and your users can co-own
> fields without clobbering each other. These are the patterns that separate a toy CRD
> from a production API.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 10.1 — CRDs](../01-custom-resource-definitions/) and [Module 10.2 — Operators](../02-kubernetes-operators/), and a local [kind](https://kind.sigs.k8s.io/) cluster (Kubernetes ≥ 1.31 for CRD field selectors).

## Learning objectives

By the end of this module you will be able to:

- Add `/status` and `/scale` **subresources** to a CRD and explain what each unlocks.
- Make a custom resource queryable with **field selectors** and **printer columns**.
- Use **Server-Side Apply** and reason about field ownership and conflicts.
- Explain **informers/indexers** and when you'd reach for an **aggregated API server**
  instead of a CRD.

---

## 1. Concept

### Subresources: one object, several endpoints

A subresource is a *second endpoint* on the same object that behaves differently from the
main one. You met `/status` in Module 10.1; `/scale` is the other common one.

- **`/status`** splits spec writes from status writes. Users `PUT` the main resource
  (spec); controllers `PUT /status`. RBAC can grant them separately, and status writes
  don't bump `metadata.generation`, so a controller can tell *"the user changed what they
  want"* from *"I updated how it's going."*
- **`/scale`** exposes a tiny, uniform `Scale` object (`spec.replicas` /
  `status.replicas` / a selector). Enabling it is what makes `kubectl scale
  environment/payments-dev --replicas=5` work **and** lets a HorizontalPodAutoscaler
  target your custom resource — because the HPA only knows how to talk to `/scale`, not
  your bespoke schema.

```yaml
subresources:
  status: {}
  scale:
    specReplicasPath: .spec.replicas      # where "desired count" lives
    statusReplicasPath: .status.replicas  # where "actual count" lives
    labelSelectorPath: .status.selector   # lets an HPA find the Pods
```

The power here is **uniformity**: by implementing the standard scale contract, every
tool that already speaks it works on your type for free.

### Field selectors and printer columns: make it queryable

By default you can only `--field-selector` a custom resource on a couple of built-in
fields (`metadata.name`, `metadata.namespace`). Declaring **`selectableFields`** lets the
API server index your own fields so the *server* filters for you:

```yaml
selectableFields:
  - jsonPath: .spec.tier
  - jsonPath: .spec.team
```

```bash
kubectl get environments --field-selector spec.tier=prod   # server-side filter
```

This matters at scale: without it, "give me all prod environments" means listing
*everything* and filtering client-side. **`additionalPrinterColumns`** is the display
counterpart — it makes `kubectl get` show the columns that matter (tier, replicas,
owner) instead of just name and age.

### Server-Side Apply: who owns which field?

`kubectl apply` historically diffed against a `last-applied-configuration` annotation
stored client-side — fragile, and blind to other writers. **Server-Side Apply (SSA)**
moves that intelligence into the API server. Every field is tagged with the **field
manager** that set it (visible in `metadata.managedFields`). When two managers try to own
the same field with different values, the server returns a **conflict** rather than
silently letting the last writer win.

```bash
kubectl apply --server-side --field-manager=user -f environment.yaml
# If the operator already owns a field you're changing:
#   conflict ... field managed by "namespace-provisioner"
kubectl apply --server-side --field-manager=user --force-conflicts -f environment.yaml
```

This is exactly what you want when an **operator** and a **human** (or two controllers)
both write to the same object: the operator owns `status` and the fields it manages, the
user owns `spec` fields, and SSA keeps them from stomping on each other. Controllers
written with controller-runtime increasingly use SSA (`client.Apply`) for precisely this
reason.

### Informers and indexers: how controllers read efficiently

A controller that did a live `LIST` on every reconcile would hammer the API server. It
doesn't. controller-runtime builds an **informer**: a local, watch-backed **cache** of
the objects you care about. Reads (`r.Get`, `r.List`) hit that cache, not the network.

When you need to look objects up by a field — "find the Environment whose
`status.namespace` is `payments-dev`" — you register an **indexer**:

```go
mgr.GetFieldIndexer().IndexField(ctx, &platformv1alpha1.Environment{},
    "status.namespace", func(o client.Object) []string {
        return []string{o.(*platformv1alpha1.Environment).Status.Namespace}
    })
// then: r.List(ctx, &list, client.MatchingFields{"status.namespace": "payments-dev"})
```

Informers + indexers are why an operator watching thousands of objects stays cheap: it
reads from memory and is notified of changes, instead of polling.

### Aggregated API servers: when a CRD isn't enough

A CRD stores its data in etcd through the main API server. Occasionally you need more
than that: custom storage (not etcd), arbitrary subresource behavior, on-the-fly computed
responses, or protobuf. For those cases you run your **own API server** and register it
with an `APIService` object so the main API server **aggregates** (proxies) a slice of the
API surface to it. The canonical example is **metrics-server**, which serves
`metrics.k8s.io` with live, uncached data that would be absurd to store in etcd.

> Reach for an aggregated API server rarely. It's a full server to build, secure, and
> operate. CRDs + CEL + webhooks cover the overwhelming majority of needs; aggregation is
> for the few percent that genuinely can't be a CRD.

---

## 2. Why it matters for platform engineering

- **Ecosystem compatibility for free.** Implement the `/scale` contract and HPAs,
  `kubectl scale`, and dashboards work on your resource with zero extra code. Standards
  beat bespoke.
- **Operability at scale.** Field selectors and printer columns turn "list everything and
  grep" into real, server-side queries — essential when there are thousands of custom
  resources.
- **Safe multi-writer automation.** SSA's field ownership is what lets an operator and a
  GitOps pipeline and an occasional human all touch the same object without a last-writer
  race. On a platform, there is *always* more than one writer.
- **Performance.** Informers and indexers keep your controllers cheap and your API server
  healthy as the fleet grows.

---

## 3. Mental model

Think of your CRD graduating from "a row in a database" to "a full API object" by adding
the facets built-in resources already have.

```text
          a bare CRD                         a first-class API object
          ──────────                         ────────────────────────
          /environments                      /environments            (spec)
                                             /environments/<n>/status (controller writes)
                                             /environments/<n>/scale  (kubectl scale, HPA)
          get by name/ns only                --field-selector spec.tier=prod
          name + age columns                 TEAM TIER REPLICAS OWNER PHASE
          last-writer-wins apply             Server-Side Apply: every field has an owner
                                             (managedFields); conflicts are surfaced
```

Rule of thumb: **anything the built-ins can do, your CRD can do too** — you just opt into
each facet (subresource, selectable field, printer column) explicitly.

---

## 4. Minimal implementation

Turn on `/scale` and a field selector, then use them — no controller required to feel the
effect:

```yaml
# in the CRD version:
subresources:
  status: {}
  scale:
    specReplicasPath: .spec.replicas
    statusReplicasPath: .status.replicas
selectableFields:
  - jsonPath: .spec.tier
```

```bash
kubectl apply --server-side -f environment-crd-v2.yaml
kubectl apply --server-side -f environment-sample.yaml

kubectl scale environment/payments-dev --replicas=5      # /scale in action
kubectl get environment payments-dev -o jsonpath='{.spec.replicas}{"\n"}'   # 5

kubectl get environments --field-selector spec.tier=prod # server-side filter
```

`kubectl scale` worked on a resource you defined, because you implemented the standard
scale contract. That's the whole theme of the module in four commands.

---

## 5. Hands-on lab

You'll upgrade the `Environment` CRD from Module 10.1 into a first-class API: add the
`/scale` subresource and `kubectl scale` it, add `selectableFields` and query by tier, add
printer columns, apply everything with **Server-Side Apply**, provoke and resolve a field
**conflict** between two managers, and add a new **CEL** rule.

➡️ **[Start the lab: Make your CRD a first-class API](./lab/README.md)**

---

## 6. Production considerations

- **Add the status subresource from day one; add `/scale` when it's meaningful.** Not
  every resource scales, but if yours has a replica-like notion, `/scale` buys you HPA and
  tooling compatibility cheaply.
- **Declare `selectableFields` for the fields people filter on**, and keep them few —
  each is an index the API server maintains. They need Kubernetes ≥ 1.31 (beta, on by
  default; 1.30 behind a feature gate).
- **Adopt Server-Side Apply for controllers.** Use a stable `fieldManager` name per
  controller so ownership is clear, and only force conflicts deliberately — a forced
  overwrite is you saying "I know better than the other manager."
- **Trust the cache, but know its limits.** Informer reads can be momentarily stale; for
  read-modify-write you still rely on `resourceVersion` optimistic concurrency on write.
- **Prefer CRDs; justify aggregation.** An aggregated API server is a long-term
  operational commitment (its own availability, certs, and upgrades). Only take it on when
  a CRD genuinely can't do the job.

---

## 7. Common mistakes

- **Enabling `/scale` without the backing fields.** — Pointing `specReplicasPath` at a
  field that isn't in the schema makes scale calls fail. *Fix:* ensure `spec.replicas` and
  `status.replicas` exist and are integers.
- **Client-side filtering at scale.** — Listing thousands of CRs and filtering in the
  client because you never declared `selectableFields`. *Fix:* declare the selectable
  fields and let the server filter.
- **Blindly `--force-conflicts`.** — Scripting `--force-conflicts` everywhere to "make the
  error go away," silently overwriting another controller's fields. *Fix:* understand who
  owns the field; force only when you intend to take ownership.
- **Two controllers, no field managers.** — Different controllers writing the same object
  with the default manager name, re-introducing last-writer-wins. *Fix:* give each
  controller a distinct, stable `fieldManager`.
- **Live-listing in the reconcile hot path.** — Bypassing the informer cache with direct
  `APIReader` list calls on every reconcile. *Fix:* read from the cached client; add an
  indexer for field lookups.
- **Reaching for an aggregated API server by default.** — Building a whole server for
  something a CRD would hold. *Fix:* start with a CRD; aggregate only when you hit a real
  CRD limitation.

---

## 8. Assessment

**Knowledge checks**

1. What does enabling the `/scale` subresource let external tools do that they couldn't
   with a bespoke `spec.replicas` field alone?
2. What problem does Server-Side Apply solve that the old client-side apply did not?
3. Why are `selectableFields` better than filtering a full list on the client?
4. What is an informer, and why does a controller read from it instead of the API server
   directly?
5. Name one situation that justifies an aggregated API server instead of a CRD.

**Concept exercise**

> Explain how you'd let both an automated controller and an occasional human safely edit
> the same object's different fields without overwriting each other — **without using the
> words "Server-Side Apply" or "field manager."** Describe the ownership model.

**Debugging / trade-off exercise**

> Your GitOps controller and your operator both manage the same `Environment`. After a
> change, `kubectl apply --server-side` from CI fails with a conflict naming the operator
> as the field's manager. Explain what this is telling you, the two legitimate ways to
> resolve it, and how you'd decide which is correct.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** It implements the standard `Scale` contract, so `kubectl scale`, a
  HorizontalPodAutoscaler, and other tools that speak `/scale` work on your resource
  without knowing its schema.
- **Q2:** SSA tracks per-field ownership on the server (`managedFields`) and surfaces
  conflicts, instead of a client-side `last-applied` annotation that silently lets the
  last writer win and can't see other writers.
- **Q3:** The API server filters server-side using an index, returning only matches;
  client-side filtering means transferring and processing every object.
- **Q4:** An informer is a local, watch-backed cache of objects; controllers read from it
  to avoid hammering the API server and to get change notifications efficiently.
- **Q5:** Serving live/computed data that shouldn't live in etcd (e.g. metrics-server),
  custom storage, or arbitrary subresource behavior a CRD can't express.
- **Debugging:** The conflict means the operator already owns that field; SSA is
  protecting you from silently clobbering it. Resolve by either (a) *not* setting that
  field in CI (let the operator own it) or (b) `--force-conflicts` to take ownership —
  correct only if the field genuinely belongs to Git, not the operator. Decide by asking
  which writer is the source of truth for that field.

</details>

---

## 9. Further reading

- Kubernetes — [CRD subresources (`/status`, `/scale`)](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/#subresources)
- Kubernetes — [Field selectors for custom resources](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/#crd-selectable-fields)
- Kubernetes — [Server-Side Apply](https://kubernetes.io/docs/reference/using-api/server-side-apply/)
- Kubernetes — [Setting up an Aggregated API server](https://kubernetes.io/docs/tasks/extend-kubernetes/setup-extension-api-server/)
- Kubernetes — [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- The Kubebuilder Book — [Watching, caches, and indexes](https://book.kubebuilder.io/reference/watching-resources)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 10.3 — Admission Webhooks](../03-admission-webhooks/)
· _Next:_ [Module 10.5 — Multi-Cluster Kubernetes →](../05-multi-cluster-kubernetes/)
