# Module 02.7 — Multi-Platform Builds and Optimization

> The last mile of containerization is making builds **fast**, **portable**, and
> **verifiable**: multi-stage builds that stay small, multi-architecture images that
> run on `amd64` and `arm64` alike, build caches that make CI quick, and
> attestations (SBOM + provenance) that prove what's inside and how it was built.
> This is how a platform ships images at scale without them becoming slow, bloated,
> or opaque.

**Estimated effort:** ~1.5 hours (theory + lab)
**You'll need:** [Module 02.2](../02-dockerfile-and-image-building/),
[Module 02.6](../06-container-registries/), and Docker with Buildx.

## Learning objectives

By the end of this module you will be able to:

- Explain **multi-stage builds** and why they keep images small (a recap that
  anchors the rest).
- Build **multi-architecture** images (`linux/amd64` + `linux/arm64`) with
  **Buildx** and QEMU.
- Use **build caches** (registry / GitHub Actions) to speed up CI.
- Attach **SBOM** and **provenance** attestations and inspect them.

---

## 1. Concept

### Recap: multi-stage builds keep images small

You met multi-stage builds in [Module 02.2](../02-dockerfile-and-image-building/);
they're the foundation for everything here. A **builder stage** has the full
toolchain (compilers, dev headers); a **runtime stage** copies out only the finished
artifact onto a minimal base:

```dockerfile
FROM golang:1.23-alpine AS build       # heavy: compiler + sources
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /app .

FROM gcr.io/distroless/static-debian12:nonroot  # tiny: just the binary
COPY --from=build /app /app
USER nonroot
ENTRYPOINT ["/app"]
```

The build toolchain never ships. You get a small, low-CVE image (Module 02.5) from a
convenient build. Everything below builds on this shape.

### One image, many CPUs: multi-architecture builds

Your laptop might be `arm64` (Apple Silicon), your CI runners `amd64`, and your
cluster nodes a mix. A plain image built on one architecture won't run on another. A
**multi-architecture image** solves this with a **manifest list** (image index): one
tag that points at several per-architecture images. The runtime automatically pulls
the variant matching the host.

```text
   app:1.0  (manifest list / image index)
      ├── linux/amd64  → sha256:aaaa…
      └── linux/arm64  → sha256:bbbb…
   `docker pull app:1.0` on an arm64 host transparently gets the arm64 variant.
```

**Buildx** (Docker's BuildKit front-end) builds these. For architectures your
machine isn't, it uses **QEMU** emulation; for compiled languages, it's faster to
**cross-compile** (set `GOARCH`/`TARGETARCH`) instead of emulating the whole build.

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t app:1.0 --push .
```

### Faster builds: BuildKit, parallelism, and caches

**BuildKit** (the engine behind `buildx`, default in modern Docker) is a big step up
from the legacy builder:

- **Parallel stages** — independent build stages run concurrently, not serially.
- **Smart caching** — only the layers whose inputs changed are rebuilt (ordering your
  Dockerfile well, per Module 02.2, is what makes this pay off).
- **Build secrets & SSH mounts** — `RUN --mount=type=secret` / `type=ssh` for
  build-time credentials that never land in a layer.

In CI, local layer cache is empty on every run, so you export the cache to somewhere
persistent and import it next time:

```yaml
# GitHub Actions: reuse BuildKit cache across runs
cache-from: type=gha
cache-to: type=gha,mode=max
# or push/pull the cache via a registry:
# cache-to:   type=registry,ref=ghcr.io/org/app:buildcache,mode=max
# cache-from: type=registry,ref=ghcr.io/org/app:buildcache
```

The difference between a 2-minute and a 15-minute pipeline is often just whether the
cache is wired up. **Remote builders** go further, running BuildKit on a beefy shared
machine so every engineer and CI job shares fast, warm caches.

### Proving what's inside: SBOM and provenance attestations

A platform shouldn't ship opaque images. Buildx can attach two **attestations** to an
image at build time:

- **SBOM** (Software Bill of Materials) — a machine-readable inventory of every
  package/dependency in the image. When the next Log4Shell lands, an SBOM answers
  "are we affected, and where?" in minutes instead of days.
- **Provenance** (SLSA) — a signed record of **how** the image was built: the source
  commit, the builder, the build parameters. It lets you verify an image came from
  your pipeline and wasn't tampered with.

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  --sbom=true --provenance=true -t app:1.0 --push .
```

These ride along in the image index as extra manifests, stored in the same registry
(Module 02.6). They're the raw material for supply-chain security (SLSA, Cosign
verification) in Phase 13.

---

## 2. Why it matters for platform engineering

This module is where container builds become a **product-grade capability** the
platform offers every team:

- **Multi-arch** means the same golden-path image runs on developer laptops, CI, and
  mixed-architecture (often cheaper `arm64`) nodes — a real cost and portability win.
- **Caching and remote builders** are the difference between a pipeline teams tolerate
  and one they love; build time is pure developer-experience friction (Module 01.3).
- **SBOM + provenance** make the platform's output *auditable and trustworthy* —
  prerequisites for the supply-chain guarantees (signing, verification, SLSA) you'll
  enforce in Phase 13.

The platform team builds this **once** — a reusable build action that does multi-arch,
caching, SBOM, and provenance — so no team reinvents it (you'll build exactly that
reusable pipeline in Phases 5–6).

## 3. Mental model

```text
  SMALL        multi-stage build → minimal base (Module 02.2 / 02.5)
  PORTABLE     buildx --platform amd64,arm64 → one tag, a manifest list
  FAST         BuildKit + parallel stages + cache-from/cache-to (CI) + remote builders
  VERIFIABLE   --sbom=true (what's inside) + --provenance=true (how it was built)

  One pipeline → one tag that is small, runs anywhere, builds fast, and proves itself.
```

One sentence: **build it small, for every CPU, quickly, and with a receipt of what's
inside and how it was made.**

## 4. Minimal implementation

Turn an ordinary build into a multi-arch, attested one with Buildx:

```bash
# 1. A builder that supports multiple platforms (QEMU is set up by Docker Desktop;
#    on Linux: docker run --privileged --rm tonistiigi/binfmt --install all)
docker buildx create --name multi --use

# 2. Build for two architectures, attach SBOM + provenance, push the manifest list
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --sbom=true --provenance=true \
  -t localhost:5000/app:1.0 --push .

# 3. Inspect: one tag, two platforms, plus attestations
docker buildx imagetools inspect localhost:5000/app:1.0
```

That's the whole module in three commands: portable, attested, from one source. The
lab runs it end to end against a local registry and reads the attestations.

## 5. Hands-on lab

Build a real **multi-architecture** image (`amd64` + `arm64`) with **SBOM** and
**provenance** attestations, push it to a local registry, and inspect the manifest
list and the attestations you attached.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **Cross-compile where you can.** Emulating a whole build under QEMU is slow;
  compiled languages should set `TARGETARCH` and cross-compile, reserving emulation
  for steps that truly need it.
- **Wire the cache in CI deliberately.** `cache-to`/`cache-from` (GHA or registry) is
  what keeps pipelines fast; measure build time with and without it.
- **Only build the architectures you run.** Each extra platform costs build time and
  storage — don't ship `arm64` if nothing runs it (yet).
- **Attach SBOM + provenance by default**, then *verify* them downstream (Cosign +
  policy, Phase 13). An attestation nobody checks is decoration.
- **Make it a reusable build action.** Teams consume one hardened, cached, attested
  build workflow rather than each writing their own (Phases 5–6).
- **Pin the builder and base images by digest** for reproducibility.

## 7. Common mistakes

- **Emulating the entire build under QEMU.** — Painfully slow CI. *Fix:* cross-compile
  with `TARGETARCH`; emulate only what must be.
- **No cache in CI.** — Every build starts cold and takes minutes. *Fix:* `cache-to`/
  `cache-from` with GHA or a registry cache.
- **Building architectures nothing runs.** — Wasted time and storage. *Fix:* build
  only the platforms you deploy to.
- **Treating the SBOM/provenance as output you never read.** — No value if unchecked.
  *Fix:* verify them in policy before deploy (Phase 13).
- **A bloated builder stage leaking into runtime.** — Forgetting the multi-stage split.
  *Fix:* copy only the artifact into a minimal runtime base.
- **Non-reproducible builds.** — Floating base tags and timestamps make digests drift.
  *Fix:* pin bases by digest; prefer reproducible build settings.

## 8. Assessment

**Knowledge checks**

1. What is a **manifest list** (image index), and how does it enable one tag to run
   on multiple CPU architectures?
2. When should you **cross-compile** instead of using QEMU emulation, and why?
3. What do `cache-to` and `cache-from` do in a CI build, and what do they improve?
4. What is the difference between an **SBOM** attestation and a **provenance**
   attestation?
5. Why is attaching an SBOM valuable the next time a widespread CVE is announced?

**Concept exercise**

> Explain how one image tag can run on both an Apple-Silicon laptop and an `amd64`
> server **without using the words "manifest" or "architecture."**

**Trade-off exercise**

> Your CI takes 14 minutes per image and only ever runs `amd64`, but a Dockerfile
> change added `--platform linux/amd64,linux/arm64` with full QEMU and no cache.
> What would you change first, and how do you decide whether `arm64` is worth
> keeping?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** A manifest list is an index that maps one tag to several per-architecture
  images; the runtime selects and pulls the entry matching the host's CPU/OS.
- **Q2:** For compiled languages, cross-compile (set `GOARCH`/`TARGETARCH`) — it's far
  faster than emulating the whole build under QEMU, which is slow.
- **Q3:** They export/import the BuildKit layer cache to persistent storage (GHA or a
  registry) so subsequent CI runs reuse unchanged layers — big build-time reduction.
- **Q4:** SBOM lists *what's inside* (packages/deps); provenance records *how it was
  built* (source, builder, parameters). One is contents, the other is lineage.
- **Q5:** You can query the SBOM to find instantly whether (and where) the vulnerable
  package is present, instead of manually auditing every image.
- **Trade-off:** First, add caching and cross-compile instead of emulating — that
  reclaims most of the time. Then decide `arm64` by demand: if nothing runs it, drop
  it (build only `amd64`); add it back when you actually deploy to `arm64` nodes
  (often cheaper), where it earns its build cost.

</details>

## 9. Further reading

- Docker — [Multi-platform images](https://docs.docker.com/build/building/multi-platform/)
  and [Buildx](https://docs.docker.com/build/concepts/overview/)
- Docker — [Build cache](https://docs.docker.com/build/cache/) and
  [cache backends](https://docs.docker.com/build/cache/backends/)
- Docker — [Build attestations: SBOM & provenance](https://docs.docker.com/build/metadata/attestations/)
- [SLSA — Supply-chain Levels for Software Artifacts](https://slsa.dev/)
- [`docker/build-push-action`](https://github.com/docker/build-push-action) (multi-arch, cache, SBOM, provenance in CI)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [02.6 — Container Registries](../06-container-registries/) · _Next phase:_ [03 · Kubernetes Fundamentals →](../../03-kubernetes-fundamentals/)
