# 02 · Containerization

> Containers are the unit of deployment the rest of this course is built on —
> Kubernetes schedules them, your CI builds them, your registry stores them, and
> your security policy governs them. Before you orchestrate containers, you need to
> understand **what a container actually is** (not magic — a few Linux kernel
> features), how images are built and shipped, and how to make them small, fast,
> and safe. This phase takes you from the kernel primitives up to production-grade,
> multi-architecture, attested images.

**Phase 2 · 7 modules · ~10–14 hours**

## Why containerization?

Phase 1 was about *what* a platform is and *who* it serves. This phase is where you
start building the machinery. Nearly every capability a modern internal developer
platform offers — a golden path to production, a paved CI pipeline, a self-service
"create a service" command — ships software as **container images**.

It is tempting to treat containers as a black box: `docker build`, `docker run`,
done. Resist that. When a container won't start, leaks data, can't talk to its
database, or ships a critical CVE to production, the engineers who can *fix* it are
the ones who understand the layers underneath the command. A platform engineer owns
those layers for every team on the platform, so you cannot afford to treat them as
magic.

This phase builds that understanding from first principles:

- **The primitives** — containers are just Linux processes with namespaces and
  cgroups. You'll build one by hand before you ever trust `docker run`.
- **Images** — how a Dockerfile becomes layers, why layer order decides your build
  speed, and how to go from a 900 MB image to a 10 MB one.
- **Networking and storage** — how containers talk to each other and how they keep
  (or lose) state, which is where most "works on my laptop" surprises come from.
- **Security** — non-root, read-only, dropped capabilities, and vulnerability
  scanning, treated as structural defaults rather than bolt-ons.
- **Registries** — how images move from a build to production safely, promoted by
  immutable digest.
- **Multi-platform builds and optimization** — shipping `amd64` + `arm64` from one
  pipeline, with caching, SBOMs, and provenance attestations.

Everything in Phase 3 (Kubernetes) assumes these fundamentals. Get them right here
and the orchestration layer becomes far easier to reason about.

## Modules

| # | Module | You'll learn | Lab deliverable |
|---|--------|--------------|-----------------|
| 1 | [Container Fundamentals](./01-container-fundamentals/) | What a container really is: namespaces, cgroups, the OCI image spec, lifecycle, and the CRI. | A container built by hand with `unshare`/cgroups, compared to Docker. |
| 2 | [Dockerfile and Image Building](./02-dockerfile-and-image-building/) | Dockerfile anatomy, layers and the build cache, multi-stage builds, base image choice, BuildKit. | One app built three ways, with a size / build-time / CVE comparison table. |
| 3 | [Container Networking](./03-container-networking/) | Bridge, host, and overlay networks; port mapping; the embedded DNS resolver; troubleshooting. | Two services talking over a custom bridge by name via DNS. |
| 4 | [Container Storage](./04-container-storage/) | The ephemeral filesystem, volumes, bind mounts, tmpfs, and storage drivers. | A database that survives restarts — and proof of what is lost without a volume. |
| 5 | [Container Security](./05-container-security/) | Non-root, read-only root, dropped capabilities, seccomp, `no-new-privileges`, and scanning. | A hardened container running under a security context, plus a Trivy scan report. |
| 6 | [Container Registries](./06-container-registries/) | Repositories, tags vs digests, image promotion, OCI artifacts, mirroring and caching. | An image promoted dev → prod by immutable digest through a local registry. |
| 7 | [Multi-Platform Builds and Optimization](./07-multi-stage-builds-and-optimization/) | Multi-arch builds with buildx + QEMU, remote caching, parallel stages, SBOM/provenance. | A multi-architecture image with SBOM and provenance attestations. |

Work them in order — each builds on the last. Together they take you from "a
container is a Linux process in a box" to "I can build a small, secure,
multi-architecture image and ship it to production with a supply-chain attestation."

## Learning objectives

By the end of this phase you will be able to:

- Explain a container in terms of the Linux kernel features that implement it
  (namespaces and cgroups), and describe the OCI image and runtime model.
- Write efficient Dockerfiles that use the build cache well, and cut image size and
  attack surface with multi-stage builds and minimal base images.
- Reason about container networking and storage well enough to debug a service that
  can't reach its dependencies or loses its data on restart.
- Harden a container to a non-root, read-only, least-privilege baseline and scan it
  for vulnerabilities before it ships.
- Operate registries and promote images safely by digest, and build attested,
  multi-architecture images in CI.

## Prerequisites

- [Phase 1 · Platform Foundations](../01-platform-foundations/) — the product and
  developer-experience lenses you'll keep applying.
- A working container runtime. Install **Docker Engine / Docker Desktop** per
  [`00-orientation/environment-setup.md`](../00-orientation/environment-setup.md).
  Windows users should run the labs inside **WSL2** (a real Linux kernel is required
  for the Module 02.1 namespace exercises).
- Comfort at a Linux shell. A few labs use `sudo` and kernel features that need
  Linux (or WSL2); each lab notes this where it matters.

## A note on cost

This phase is designed to run **entirely free on your laptop**. Every lab uses
local Docker, a local registry container, and open-source scanners — no cloud spend
required. Where a step *could* incur cost (for example pushing to a hosted registry
or using CI minutes), it is clearly marked with a cost note and a cleanup step.
Always run the **Cleanup** section at the end of each lab: containers, volumes, and
images left running consume disk and memory.

---

Start with [**02.1 · Container Fundamentals →**](./01-container-fundamentals/)
