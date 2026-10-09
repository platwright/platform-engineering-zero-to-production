# Lab — Build a multi-architecture, attested image

> You'll build one image for **two CPU architectures** at once, attach **SBOM** and
> **provenance** attestations, push the result to a local registry, and inspect the
> manifest list and attestations. All local and free.

**Estimated time:** ~40–60 minutes
**Type:** Build
**Deliverable:** A multi-arch (`amd64` + `arm64`) image in a local registry, carrying
SBOM and provenance attestations, plus the `imagetools inspect` output proving it.

## Objectives

- Use Buildx to build for multiple platforms from one Dockerfile.
- Attach and inspect SBOM and provenance attestations.
- Read a manifest list (image index).

## Prerequisites

- Docker with **Buildx** (`docker buildx version`) — included in Docker Desktop and
  recent Docker Engine. See
  [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md).
- On Linux, enable emulation once if needed:
  `docker run --privileged --rm tonistiigi/binfmt --install all`.
- Starter files in this folder: [`Dockerfile`](./Dockerfile), [`main.go`](./main.go),
  [`go.mod`](./go.mod). No cost — all local.

## Steps

1. **Start a local registry** (multi-arch manifest lists and attestations need a
   registry to push to):

   ```bash
   docker run -d -p 5000:5000 --name registry registry:2
   ```

2. **Create a Buildx builder** that can target multiple platforms:

   ```bash
   docker buildx create --name multi --use
   docker buildx inspect --bootstrap        # shows the platforms it supports
   ```

3. **Build for two architectures with SBOM + provenance, and push:**

   ```bash
   docker buildx build \
     --platform linux/amd64,linux/arm64 \
     --sbom=true --provenance=true \
     -t localhost:5000/multiarch:1.0 \
     --push .
   ```

   Because the Dockerfile cross-compiles (it reads `TARGETARCH`), both variants build
   quickly without emulating the whole toolchain.

4. **Inspect the manifest list — one tag, two platforms, plus attestations:**

   ```bash
   docker buildx imagetools inspect localhost:5000/multiarch:1.0
   ```

   You should see `linux/amd64` and `linux/arm64` entries, plus attestation manifests
   (`vnd.in-toto`/SBOM/provenance) attached to each.

5. **Read the attestations you attached:**

   ```bash
   docker buildx imagetools inspect localhost:5000/multiarch:1.0 \
     --format '{{ json .SBOM }}' | head -c 600; echo
   docker buildx imagetools inspect localhost:5000/multiarch:1.0 \
     --format '{{ json .Provenance }}' | head -c 600; echo
   ```

6. **Run it on your machine — the right variant is pulled automatically:**

   ```bash
   docker run --rm localhost:5000/multiarch:1.0
   # -> hello from linux/amd64   (or linux/arm64 on Apple Silicon)
   ```

## Expected result

- `imagetools inspect` lists **both** platforms under one tag, with SBOM and
  provenance attestations attached.
- Running the image prints the architecture matching your host — you never had to
  pick a variant by hand.

## Cleanup

```bash
docker buildx rm multi 2>/dev/null || true
docker rm -f registry 2>/dev/null || true
docker rmi localhost:5000/multiarch:1.0 2>/dev/null || true
```

## Reflection

- You built `arm64` on (likely) an `amd64` machine with no QEMU for the compile.
  Why is cross-compiling so much faster than emulating the whole build?
- The SBOM lists every dependency in the image. How would you use it the day a
  widespread CVE is announced?
- In CI the layer cache starts empty each run. Which `cache-to`/`cache-from` setup
  (from the lesson) would you add, and what would you expect it to save?

## Stretch goals (optional)

- Add registry build caching and time a warm vs cold build:
  `--cache-to type=registry,ref=localhost:5000/multiarch:buildcache,mode=max`
  and `--cache-from type=registry,ref=localhost:5000/multiarch:buildcache`.
- If your registry rejects attestations, push to GHCR instead (Module 02.6) and
  inspect there — the commands are identical.
