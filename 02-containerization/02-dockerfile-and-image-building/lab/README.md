# Lab — Build one app three ways

> You'll containerize the **same** tiny Go web service three ways — a naive
> single-stage image, a multi-stage image, and a distroless image — then measure what
> each choice costs in **size, build time, package count, and CVE exposure**. By the end
> you'll have hard numbers showing why multi-stage builds on a minimal base are the
> sensible default on a platform.

**Estimated time:** ~45–60 minutes
**Type:** Build / compare
**Deliverable:** A filled-in comparison table of **image size, build time, OS-package
count, and HIGH/CRITICAL CVE count** for the three builds (the template is the final
step).

## Objectives

- Build one program with three Dockerfiles and explain why the images differ in size.
- Measure image size and build time, and use a scanner to count packages and CVEs.
- Show that a distroless image has **no shell**, shrinking the attack surface.
- Justify a base-image choice with evidence rather than habit.

## Prerequisites

- **Docker with BuildKit** (the default in modern Docker). On Windows, run everything
  inside **WSL2** — a real Linux kernel. Verify Docker works: `docker run --rm hello-world`.
- **Trivy**, a free, open-source image scanner. Either install the binary:

  ```bash
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b /usr/local/bin
  ```

  …or run it as a container (no install), which this lab uses throughout:

  ```bash
  docker run --rm aquasec/trivy --version
  ```

- Everything from
  [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  that this lab relies on (a working Docker daemon).
- The starter files already in this folder: [`main.go`](./main.go), [`go.mod`](./go.mod),
  [`.dockerignore`](./.dockerignore), [`Dockerfile.single`](./Dockerfile.single),
  [`Dockerfile.multi`](./Dockerfile.multi), and
  [`Dockerfile.distroless`](./Dockerfile.distroless).

## Steps

1. **Enter the lab directory and review the app.**

   ```bash
   cd 02-containerization/02-dockerfile-and-image-building/lab
   ls
   cat main.go      # a ~15-line HTTP server that prints "hello from a container"
   ```

   All three Dockerfiles build this identical program — only the **packaging** differs.

2. **Build all three images**, timing each for the comparison table. The first build
   pulls the shared `golang:1.22` base, so run them in this order and note each time:

   ```bash
   time docker build -f Dockerfile.single     -t hello:single     .
   time docker build -f Dockerfile.multi      -t hello:multi      .
   time docker build -f Dockerfile.distroless -t hello:distroless .
   ```

   `-f` selects a Dockerfile; `-t` tags the result. BuildKit also prints a per-step
   timing breakdown you can read above each total.

3. **Compare image size.**

   ```bash
   docker images hello
   ```

   ```text
   REPOSITORY   TAG          SIZE
   hello        single       ~800MB     <- ships the whole Go toolchain
   hello        multi        ~90MB      <- static binary on debian:12-slim
   hello        distroless   ~10MB      <- static binary, no OS userland
   ```

   Same program, roughly **80× difference**. The toolchain and OS userland — not your
   code — are the weight.

4. **Prove all three actually run.**

   ```bash
   docker run --rm -d -p 8080:8080 --name hello hello:distroless
   sleep 1
   curl -s localhost:8080      # -> hello from a container
   docker rm -f hello
   ```

   The 10 MB distroless image serves the same response as the 800 MB one.

5. **Measure attack surface: the shell test.** A shell inside an image is a gift to an
   attacker. Count executables in the single-stage image, then show distroless has none:

   ```bash
   docker run --rm --entrypoint sh hello:single -c "ls /bin /usr/bin | wc -l"
   # hundreds of binaries (sh, apt, and friends)

   docker run --rm --entrypoint sh hello:distroless -c "echo hi"
   # error: "sh": executable file not found -> there IS no shell
   ```

   No shell means no `sh`, no `apt`, no `curl` for an attacker who lands inside.

6. **Scan each image for CVEs with Trivy.** Read the **Total** and the HIGH/CRITICAL
   counts from each summary; Trivy also reports the number of OS **packages** it found,
   which is your "packages" column:

   ```bash
   docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
     aquasec/trivy image --scanners vuln hello:single
   docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
     aquasec/trivy image --scanners vuln hello:multi
   docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
     aquasec/trivy image --scanners vuln hello:distroless
   ```

   With a local `trivy` binary the command is simply `trivy image --scanners vuln
   hello:single`. Fewer packages means fewer things that can carry a CVE.

7. **Record your results — the deliverable.** Fill in the table with what you measured in
   steps 2–6.

   | Image | Size | Build time | OS packages | HIGH/CRITICAL CVEs |
   |-------|------|------------|-------------|--------------------|
   | `hello:single` | | | | |
   | `hello:multi` | | | | |
   | `hello:distroless` | | | | |

   Size, package count, and CVE count should all **fall** as you move down the table,
   while the program's behaviour stays identical.

## Expected result

A completed table with a clear ordering — single ≫ multi > distroless — on every axis
that matters:

- **Size:** roughly `~800MB` → `~90MB` → `~10MB` (about **80× smaller**).
- **Packages / CVEs:** the single-stage image carries the whole Go toolchain and a full
  Debian userland (hundreds of packages, many HIGH/CRITICAL CVEs); multi-stage drops the
  toolchain; **distroless reports few or often zero** OS-package CVEs.
- **Attack surface:** `hello:single` has a shell and package manager; **`hello:distroless`
  has no shell at all**, so the shell test fails by design.

If distroless shows more CVEs than expected, re-check that you built from the `:nonroot`
static base and that the binary is static (`CGO_ENABLED=0`).

## Cleanup

> Everything here is free and local — no cloud resources — but the images use real disk.
> Always remove them when you're done.

```bash
# Remove the three images you built:
docker rmi hello:single hello:multi hello:distroless

# Remove the base and scanner images you pulled (optional):
docker rmi golang:1.22 debian:12-slim gcr.io/distroless/static-debian12:nonroot
docker rmi aquasec/trivy 2>/dev/null || true

# Reclaim dangling build cache:
docker builder prune -f
```

## Reflection

- Which single change bought the biggest size drop — adding the second stage, or
  switching the runtime base to distroless? Why?
- The distroless image has no shell, so `docker exec … sh` won't work. How would you
  debug it in production? (Hint: a dedicated debug image, or `kubectl debug` ephemeral
  containers — Module 02.5 / Phase 3.)
- Where in a platform's golden-path template would you put the "right" Dockerfile so
  every team gets these wins by default?

## Stretch goals (optional)

- Bust the context on purpose: create a big file (`dd if=/dev/zero of=big.bin bs=1M
  count=200`), rebuild, and watch the "transferring context" size balloon — then add
  `big.bin` to [`.dockerignore`](./.dockerignore) and confirm it shrinks back.
- Change [`Dockerfile.multi`](./Dockerfile.multi)'s runtime stage from `debian:12-slim`
  to `scratch` (the binary is already static). How much smaller is it, and what breaks
  (for example missing CA certificates for outbound TLS)?
- Add a BuildKit cache mount
  (`RUN --mount=type=cache,target=/root/.cache/go-build go build …`) and compare a warm
  rebuild time against the cold build from step 2.
