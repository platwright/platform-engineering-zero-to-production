# Module 07.5 — OCI Artifacts and Distribution

> The registry that stores your container images can store *far* more: Helm charts,
> SBOMs, signatures, provenance attestations, even Wasm modules. The OCI specs turned
> container registries into a **universal, content-addressable store for platform
> artifacts**. This module shows how charts travel as OCI artifacts (`helm push`/
> `pull oci://`), how ORAS pushes anything else, and why one distribution plane for
> everything is a platform superpower.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** [Module 07.2](../02-helm-chart-development/), `kubectl` + [kind](https://kind.sigs.k8s.io/), [Helm](https://helm.sh/) 3.8+, and Docker (for a local `registry:2`).

## Learning objectives

By the end of this module you will be able to:

- Explain what an **OCI artifact** is and why a registry can store more than images.
- Push and pull a Helm chart as an OCI artifact with `helm push` / `helm pull oci://`.
- Use **ORAS** to store arbitrary artifacts (an SBOM, a config blob) in a registry.
- Describe how **SBOMs, signatures, and attestations** attach to what they describe.
- Reason about distribution in production: digests, signing, retention, air-gaps.

---

## 1. Concept

### A registry is a content-addressable object store

Under the hood, an OCI registry doesn't know or care about "images." It stores three
kinds of things, addressed by **digest** (a SHA-256 of the content):

- **Blobs** — opaque bytes (a tarball layer, a chart archive, a JSON document).
- **A manifest** — a small JSON document that lists a `config` blob and an ordered set
  of `layers` (blobs), each tagged with a **media type** that says what it is.
- **Tags** — human-friendly names (`1.0.0`) that point at a manifest digest.

An "image" is just one *convention* on top of this: a manifest whose config media type
is `application/vnd.oci.image.config.v1+json` and whose layers are filesystem tarballs.
Change the media types and the *same* machinery stores something else entirely. That's
the key insight: **the registry is generic; "image" is one artifact type among many.**

### OCI artifacts: everything beyond images

The [OCI Image](https://github.com/opencontainers/image-spec) and
[Distribution](https://github.com/opencontainers/distribution-spec) specs formalize
this. An **artifact** is any manifest whose `config.mediaType` (or, in OCI 1.1, an
`artifactType`) marks it as "not a runnable image." Registries that implement the spec
can therefore store:

- **Helm charts** (`application/vnd.cncf.helm.chart.content.v1.tar+gzip`),
- **SBOMs** (SPDX/CycloneDX documents describing an image's contents),
- **Signatures and attestations** (cosign/Sigstore, SLSA provenance),
- **Wasm modules**, Terraform modules, policy bundles, ML models, and more.

One registry, one auth model, one replication story — for *all* of it.

### Helm charts as OCI artifacts

Helm 3.8+ treats OCI registries as a first-class chart repository. There's no separate
`index.yaml` to host; the registry *is* the index:

```text
helm package ./platform-app                       # → platform-app-1.0.0.tgz
helm push platform-app-1.0.0.tgz oci://<registry>/charts
# stored at <registry>/charts/platform-app:1.0.0 as an OCI artifact

helm show chart   oci://<registry>/charts/platform-app --version 1.0.0
helm pull         oci://<registry>/charts/platform-app --version 1.0.0
helm install web  oci://<registry>/charts/platform-app --version 1.0.0
```

The chart's `version` becomes the OCI tag. `helm registry login` handles auth the same
way `docker login` does — because it's the same registry API.

### ORAS: push *anything* to a registry

[ORAS](https://oras.land/) ("OCI Registry As Storage") is the generic CLI for
artifacts that aren't images or charts. It pushes files as blobs with media types you
choose:

```text
oras push <registry>/sboms/web:1.0.0 \
  --artifact-type application/vnd.example.sbom \
  sbom.spdx.json:application/spdx+json
# pull it back anywhere with:
oras pull <registry>/sboms/web:1.0.0
```

Where `helm push` is chart-specific, ORAS is the Swiss-army knife: SBOMs, config
bundles, test fixtures, signed metadata — any bytes you want distributed through the
registry you already run.

### Attaching metadata: the referrers graph

Supply-chain metadata is most useful *attached to the thing it describes*. OCI 1.1
adds a **`subject`** field: an artifact manifest can declare that it *refers to*
another manifest (an image, a chart). The registry's **Referrers API** then lets you
ask "what SBOMs/signatures/attestations are attached to this image digest?"

```text
image:1.0.0 (digest sha256:abc…)
   ├── refers ◀── SBOM          (subject = sha256:abc…)
   ├── refers ◀── cosign signature
   └── refers ◀── SLSA provenance attestation
```

This is how `cosign sign`/`cosign attest` and `oras attach` work: they push a new
artifact whose `subject` is the image, so the signature and SBOM travel *with* the
image and are discoverable by digest — no side database required.

### The platform distribution pattern

Put it together and a platform gets **one distribution plane**:

```text
CI builds → pushes to ONE registry:
  the image           (app:1.0.0)
  + its SBOM          (attached by digest)
  + its signature     (cosign, attached by digest)
  + the golden-path chart (oci://…/charts/platform-app:1.0.0)

Clusters/consumers pull by digest; admission verifies signatures before running.
```

Everything the platform ships — code, config, and the metadata that makes it
trustworthy — flows through infrastructure you already operate for images.

---

## 2. Why it matters for platform engineering

- **One plane to secure and operate.** Auth, RBAC, quotas, retention, geo-replication,
  and air-gap mirroring that you already run for images now cover charts and
  supply-chain metadata too. You don't stand up a second system for chart hosting.
- **The golden-path chart becomes a real dependency.** Teams `helm install
  oci://…/charts/platform-app --version 1.4.2` exactly like pulling a library. Pin it,
  audit it, roll it forward — it's a versioned artifact in the registry.
- **Supply-chain security gets a home.** SBOMs, signatures, and provenance live *next
  to* the artifacts they describe, discoverable by digest. That's the foundation for
  "only signed, SBOM-backed images run here" admission policy (Phase on security).
- **It's how GitOps and clusters consume packages.** Argo CD and clusters pull charts
  and images from the registry; a single registry endpoint is far simpler to secure
  and mirror than a sprawl of HTTP chart repos and ad-hoc file servers.

---

## 3. Mental model

Think of the registry as a **content-addressable warehouse**, and every artifact as a
labeled crate referenced by the hash of its contents:

```text
        ┌──────────────────────── OCI REGISTRY ────────────────────────┐
        │  content-addressable store: everything keyed by sha256 digest │
        │                                                               │
        │   MANIFEST (json)  ── config.mediaType / artifactType ──┐     │
        │      │  lists blobs + media types                        │    │
        │      ├── blob: fs layer        → it's an IMAGE           │    │
        │      ├── blob: chart .tgz      → it's a HELM CHART       │    │
        │      ├── blob: sbom.json       → it's an SBOM            │    │
        │      └── subject: sha256:abc…  → ATTACHED to another one │    │
        │                                                          ▼    │
        │   tag "1.0.0" ───────────────▶ points at a manifest digest    │
        └───────────────────────────────────────────────────────────────┘

   The media type is the ONLY thing that makes bytes "an image" vs "a chart" vs
   "an SBOM." Same warehouse, different labels.
```

The durable rule: **a registry stores artifacts, not images.** Images, charts, SBOMs,
and signatures are all just manifests + blobs + media types — and digests make them
immutable and verifiable.

## 4. Minimal implementation

Run a throwaway registry, then push and pull a chart as an OCI artifact — no cloud, no
account:

```bash
# A local OCI registry in one container
docker run -d -p 5000:5000 --name registry registry:2

# Package a chart and push it; the chart version becomes the OCI tag
helm package ./platform-app                         # → platform-app-1.0.0.tgz
helm push platform-app-1.0.0.tgz oci://localhost:5000/charts

# Pull it back and inspect — the registry IS the index
helm show chart oci://localhost:5000/charts/platform-app --version 1.0.0
helm pull oci://localhost:5000/charts/platform-app --version 1.0.0
```

That's the whole distribution loop: a versioned, content-addressed chart living in the
same kind of registry as your images. The lab extends it with a cluster install and an
ORAS-pushed SBOM.

## 5. Hands-on lab

You'll stand up a local `registry:2`, package the hardened `platform-app` chart, push
it as an OCI artifact, pull it back, install it onto kind straight from the registry,
and (stretch) attach an SBOM with ORAS.

➡️ **[Start the lab: Package and distribute a chart via OCI](./lab/README.md)**

## 6. Production considerations

- **Pin by digest, not just tag.** Tags are mutable; a digest (`@sha256:…`) is the
  exact bytes. Production installs and admission policies should reference digests so a
  retag can't swap what runs.
- **Sign and verify.** Sign charts and images (cosign/Sigstore), store the signatures
  as referrers, and *verify* at admission. An unsigned-but-pushed artifact is just a
  convenient way to ship an attack.
- **Registry RBAC, retention, and GC.** Scope who can push to `charts/` vs `images/`,
  set tag-retention/immutability, and run garbage collection — artifacts accumulate
  fast and untagged blobs cost money.
- **Air-gapped and multi-region.** One of OCI's biggest wins: mirror/replicate the
  *whole* artifact set (images + charts + metadata) with the same tooling. Plan
  pull-through caches and promotion between registries.
- **Mind registry support levels.** The OCI 1.1 Referrers API and arbitrary
  `artifactType`s aren't uniformly supported; some managed registries lag. Confirm
  your registry supports what your signing/SBOM workflow needs, or use the tag-schema
  fallback.
- **Rate limits and availability.** If every pod pull and every CI job hits one
  registry, it's a availability and cost hotspot. Cache aggressively; treat the
  registry as tier-1 infrastructure.

## 7. Common mistakes

- **Treating OCI charts like HTTP repos.** — Running `helm repo add` against an
  `oci://` URL, or expecting an `index.yaml`. *Fix:* there's no `repo add` for OCI; you
  reference `oci://…/chart --version X` directly, and `helm registry login` for auth.
- **Pushing unsigned, unscanned artifacts.** — "It's in the registry" is mistaken for
  "it's trustworthy." *Fix:* sign (cosign), scan, and attach an SBOM; verify at
  admission.
- **Pinning only by tag.** — A mutable tag gets re-pushed and your "known-good" release
  changes under you. *Fix:* record and deploy the digest.
- **Forgetting the chart version *is* the tag.** — Pushing two different charts with the
  same `version` overwrites the tag. *Fix:* bump `Chart.yaml` `version` on every change;
  treat it as immutable once published.
- **No retention/GC policy.** — The registry balloons with old tags and dangling blobs.
  *Fix:* set retention and run garbage collection from day one.
- **Assuming every registry supports every artifact type.** — The Referrers API or a
  custom `artifactType` silently fails on an older registry. *Fix:* check support; fall
  back to the referrers tag schema where needed.

## 8. Assessment

**Knowledge checks**

1. What actually makes a set of bytes in a registry "an image" versus "a Helm chart"
   versus "an SBOM"?
2. How do you consume a chart from an OCI registry, and how does that differ from a
   classic HTTP Helm repo?
3. What is the `subject` field / Referrers API for, and what does it enable?
4. Why pin a production deployment to a digest rather than a tag?
5. Name three artifact types — beyond images — that a platform might distribute through
   one OCI registry.

**Concept exercise**

> Explain how one registry can distribute your app, its configuration package, and the
> metadata that proves it's trustworthy — **without using the words "Docker" or
> "image."** Describe blobs, manifests, media types, and digests.

**Architecture / trade-off exercise**

> Your org hosts Helm charts on an HTTP chart repo (a static site with `index.yaml`)
> and images in a container registry. Make the case for consolidating charts into the
> OCI registry: what do you gain (security, ops, supply chain), what could break
> (tooling that expects `repo add`, registries lacking Referrers support), and how
> would you migrate without a flag day?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** The media types (and OCI 1.1 `artifactType`) on the manifest's config/layers.
  Same manifest+blobs machinery; the labels decide what it is.
- **Q2:** Reference it directly: `helm install name oci://registry/charts/app
  --version X` (with `helm registry login` for auth). No `helm repo add`, no hosted
  `index.yaml` — the registry is the index.
- **Q3:** `subject` links an artifact (SBOM, signature, provenance) to the manifest it
  describes; the Referrers API lists everything attached to a digest — so metadata
  travels with the artifact and is discoverable without a side database.
- **Q4:** Tags are mutable and can be re-pushed; a digest is the exact immutable bytes,
  so deploying/verifying by digest guarantees you run precisely what you reviewed.
- **Q5:** e.g. Helm charts, SBOMs (SPDX/CycloneDX), cosign signatures, SLSA provenance
  attestations, Wasm modules, Terraform/policy bundles.
- **Trade-off:** Gains: one auth/RBAC/retention/replication plane, supply-chain
  metadata attached by digest, simpler air-gap mirroring. Risks: tooling/CI that
  assumes `repo add`/`index.yaml`, and registries without Referrers/`artifactType`
  support. Migrate by dual-publishing (HTTP repo + OCI) for a deprecation window, then
  cut consumers over.

</details>

## 9. Further reading

- OCI — [Image Format Specification](https://github.com/opencontainers/image-spec)
- OCI — [Distribution Specification (incl. Referrers API)](https://github.com/opencontainers/distribution-spec)
- Helm — [Registries (OCI support)](https://helm.sh/docs/topics/registries/)
- ORAS — [Documentation](https://oras.land/docs/)
- [Artifact Hub](https://artifacthub.io/) — discovering charts and other CNCF artifacts
- Sigstore — [cosign (signing images and artifacts)](https://docs.sigstore.dev/cosign/signing/overview/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 07.4 — Helm vs Kustomize](../04-helm-vs-kustomize/)
· _Next phase:_ [08 · GitOps →](../../08-gitops/)
