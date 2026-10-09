# Module 02.6 — Container Registries

> A registry is where images live between "built" and "running." It's also where a
> platform enforces one of its most important guarantees: that the exact bytes you
> tested in dev are the exact bytes that run in production. This module covers
> repositories, **tags vs digests**, promotion by **immutable digest**, registry
> security, and the fact that registries store far more than images.

**Estimated effort:** ~1–1.5 hours (theory + lab)
**You'll need:** [Module 02.2](../02-dockerfile-and-image-building/) and Docker.

## Learning objectives

By the end of this module you will be able to:

- Define a **repository**, a **tag**, and a **digest**, and explain why tags are
  mutable but digests are not.
- Promote an image from dev to prod **by digest** so the bytes never change.
- Describe registry **security** controls (scan-on-push, access control) and the
  main public/private registries.
- Explain that a registry stores **OCI artifacts** (charts, SBOMs, signatures), not
  just images.

---

## 1. Concept

### What a registry is

A **container registry** is a content-addressable store and API for distributing
images. You `push` images to it and `pull` them from it. The address of an image has
three parts:

```text
   ghcr.io / your-org / checkout-service : 1.4.2
   └──────┘ └────────────────────────┘  └─────┘
   registry        repository             tag
```

- **Registry** — the host (Docker Hub, GHCR, Google Artifact Registry, ECR, a
  self-hosted Harbor).
- **Repository** — a named collection of versions of one image.
- **Tag** — a human-friendly, **movable** label pointing at a specific image.

### Tags are mutable; digests are not

This is the idea the whole module turns on.

- A **tag** (`:1.4.2`, `:latest`) is a *pointer*. Someone can push different content
  to the same tag tomorrow. `:latest` especially is a moving target.
- A **digest** (`@sha256:9f86d0…`) is the **content address** — a cryptographic hash
  of the image's exact bytes. If the content changes by a single byte, the digest
  changes. `app@sha256:9f86d0…` always refers to the *same image, forever*.

```text
   checkout:1.4.2   ──►  sha256:aaaa…   (today)
   checkout:1.4.2   ──►  sha256:bbbb…   (after someone re-pushes the tag!)

   checkout@sha256:aaaa…  ──►  sha256:aaaa…   (immutable, always)
```

For anything you care about — production deploys, promotion, signatures — **refer to
images by digest, not by tag.** Tags are for humans; digests are for machines and for
guarantees.

### Image promotion by digest

A core platform pattern: build an image **once**, then move that *same digest*
through environments. Don't rebuild per environment — a rebuild can produce different
bytes (new base-image CVEs, nondeterministic builds) and silently diverge what you
tested from what you ship.

```text
build once ──► scan ──► sign ──► push  ──►  checkout@sha256:aaaa…
                                                 │  (the same bytes)
             dev  deploys  checkout@sha256:aaaa…─┤
          staging deploys  checkout@sha256:aaaa…─┤
             prod deploys  checkout@sha256:aaaa…─┘
```

"Promotion" is just *marking a known-good digest as approved for the next
environment* (often by adding a tag like `:prod` to the same digest, or recording the
digest in that environment's GitOps config). The bytes never change.

### Public and private registries

- **Docker Hub** — the default public registry; mind its rate limits.
- **GHCR** (GitHub Container Registry) — integrates with GitHub repos/Actions;
  used in this course's CI.
- **Google Artifact Registry / Amazon ECR / Azure ACR** — cloud-native registries
  with IAM integration (Artifact Registry is the course's cloud default).
- **Harbor** — a popular self-hosted registry with built-in scanning, RBAC,
  replication, and signing — when you need to run your own.

### Registry security

A registry is a supply-chain chokepoint, so it's a good place to enforce controls:

- **Scan on push** — reject or flag images with critical CVEs as they arrive (Harbor
  and cloud registries can do this; you'll also gate in CI, Phase 5).
- **Access control** — who can push vs pull which repositories (least privilege; CI
  gets a narrow push token, not a human's credentials).
- **Immutability / retention** — prevent overwriting released tags; expire old ones.
- **Signature verification** — only allow signed images to be pulled/deployed
  (Cosign + policy, Phase 13).

### Registries store more than images (OCI artifacts)

The OCI distribution spec lets a registry store **any** content, not just container
images: Helm charts, **SBOMs**, **signatures/attestations**, Wasm modules, even
arbitrary files. This is why your registry becomes the platform's artifact hub —
`helm push` to a registry (Phase 6), store an SBOM next to its image (Phase 13), all
in the same place with the same auth. Tools like `oras`, `crane`, and `skopeo`
operate on registries without a Docker daemon.

### Mirroring and caching

For speed, reliability, and **air-gapped** environments, registries can be
**mirrored** (a local copy of upstream images) or run as a **pull-through cache**.
This removes a hard dependency on the public internet (and Docker Hub rate limits)
for every build and deploy.

---

## 2. Why it matters for platform engineering

The registry is where the platform guarantees **integrity and traceability** of what
runs:

- **Promotion by digest** is how you promise "what we tested is what we shipped." A
  platform that promotes by mutable tag can't make that promise.
- **Scan-on-push and access control** make the registry a policy enforcement point,
  not just storage.
- **One artifact hub** (images, charts, SBOMs, signatures) simplifies the whole
  supply chain — one place, one auth model, one audit trail.

Later phases build directly on this: GitOps (Phase 7) pins deployments to digests,
CI (Phase 5) pushes by digest and signs, and security (Phase 13) verifies signatures
before admission.

## 3. Mental model

```text
  TAG (mutable pointer)         DIGEST (immutable content address)
  checkout:1.4.2  ─────────►    checkout@sha256:aaaa…
        ▲                               ▲
   for humans                     for guarantees
   can move                       never moves
   use in dev convenience         use for promotion, signing, prod deploys

  Build ONCE → push a digest → promote the SAME digest dev → staging → prod.
  The registry also holds charts, SBOMs, and signatures — not just images.
```

One sentence: **tags name images for people; digests pin images for machines —
promote by digest so the bytes never change.**

## 4. Minimal implementation

You don't need a cloud account to understand registries — run one locally:

```bash
# Start a registry on localhost:5000
docker run -d -p 5000:5000 --name registry registry:2

# Push an image to it, then look at the digest the registry assigned
docker tag alpine:3.20 localhost:5000/demo:dev
docker push localhost:5000/demo:dev          # prints: digest: sha256:…

# Pull that exact content by digest — immutable, tag-independent
docker pull localhost:5000/demo@sha256:<the-digest>
```

That's the whole model in four commands: a repository (`demo`), a tag (`dev`), and a
digest you can pin to. The lab turns this into a real dev → prod promotion.

## 5. Hands-on lab

Run a local registry, push an image, prove that a **tag** can change while a
**digest** cannot, and promote an image from dev to prod **by digest** — the exact
bytes moving between environments.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **Deploy by digest in production.** Pin workloads to `repo@sha256:…`, not `:latest`
  or a floating tag, so a re-pushed tag can never silently change prod.
- **Lock released tags.** Make release tags immutable so they can't be overwritten;
  expire throwaway dev tags to control storage.
- **Least-privilege registry access.** CI gets a scoped push token for specific
  repositories; humans generally don't push to prod repos at all.
- **Scan on push and verify signatures on pull.** Make the registry and admission
  layer refuse unsafe or unsigned images.
- **Mirror/cache upstream images.** Remove the public internet (and Docker Hub rate
  limits) from your critical build/deploy path; essential for air-gapped setups.
- **Treat the registry as tier-1 infrastructure.** If it's down, nothing deploys —
  give it the availability and backups that importance implies.

## 7. Common mistakes

- **Deploying `:latest` to production.** — It's a moving pointer; two deploys can run
  different code. *Fix:* deploy by immutable digest.
- **Rebuilding per environment.** — The prod image can differ from the one you tested
  (new base CVEs, nondeterminism). *Fix:* build once, promote the same digest.
- **Overwriting a released tag.** — Destroys traceability and can poison caches.
  *Fix:* immutable release tags; promote by digest.
- **Using a human's credentials in CI.** — Broad, long-lived, and risky. *Fix:* a
  scoped, short-lived push token (OIDC in Phase 5).
- **Ignoring Docker Hub rate limits.** — Builds fail intermittently under load.
  *Fix:* authenticate and/or run a pull-through cache/mirror.
- **Treating the registry as "just storage."** — It's a supply-chain control point.
  *Fix:* enable scan-on-push, access control, and signature verification.

## 8. Assessment

**Knowledge checks**

1. What is the difference between a **tag** and a **digest**, and which should a
   production deployment reference?
2. What does "promote by digest" mean, and what problem does it prevent?
3. Name two security controls a registry can enforce.
4. Besides container images, name two other things an OCI registry can store.
5. Why would an organization run a **pull-through cache** or mirror?

**Concept exercise**

> Explain why you should ship the *same* image from dev to production **without using
> the words "tag" or "digest."** Describe what could go wrong otherwise.

**Trade-off exercise**

> A team deploys `app:latest` everywhere and says it's simpler. A recent prod
> incident was traced to "the image changed but the tag didn't." How do you move them
> to digest-based deploys with minimal friction, and what do they gain?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** A tag is a mutable, human-friendly pointer that can be moved to new content;
  a digest is the immutable `sha256` content address. Production should reference the
  **digest**.
- **Q2:** Promoting the *same digest* (same exact bytes) through environments instead
  of rebuilding — it prevents "what we tested" from diverging from "what we shipped."
- **Q3:** Any two of: scan-on-push, access control (push/pull RBAC), tag immutability/
  retention, signature verification.
- **Q4:** Any two of: Helm charts, SBOMs, signatures/attestations, Wasm modules,
  arbitrary files.
- **Q5:** To avoid depending on the public internet for every pull (speed,
  reliability, Docker Hub rate limits) and to support air-gapped environments.
- **Trade-off:** Have CI output the built digest and pin deploys to `app@sha256:…`
  (store it in the environment's config/GitOps). They keep a readable tag for humans
  but deploy an immutable digest, so a re-pushed tag can never change prod again —
  exactly the incident they just had, prevented.

</details>

## 9. Further reading

- [OCI Distribution Specification](https://github.com/opencontainers/distribution-spec)
- Docker — [Run a local registry (`registry:2`)](https://hub.docker.com/_/registry)
- [GitHub Container Registry (GHCR)](https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Google Artifact Registry](https://cloud.google.com/artifact-registry/docs) ·
  [Harbor](https://goharbor.io/)
- [`crane`](https://github.com/google/go-containerregistry/blob/main/cmd/crane/doc/crane.md),
  [`skopeo`](https://github.com/containers/skopeo), and
  [ORAS](https://oras.land/) — registry tooling without a daemon

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [02.5 — Container Security](../05-container-security/) · _Next:_ [02.7 — Multi-Platform Builds and Optimization](../07-multi-stage-builds-and-optimization/)
