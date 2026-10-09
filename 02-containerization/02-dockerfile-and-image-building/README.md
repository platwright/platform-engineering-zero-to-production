# Module 02.2 — Dockerfile and Image Building

> A Dockerfile is a **reproducible recipe** that turns source into an immutable,
> layered image. The default image most teams ship is slow to rebuild and carries
> hundreds of megabytes of toolchain it never runs — because the layer-and-cache model
> isn't obvious until someone shows you. This module makes it obvious: fast builds,
> small images.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** [Module 02.1 · Container Fundamentals](../01-container-fundamentals/)
(what a layer and the OCI image model are) and Docker **with BuildKit** — default in
modern Docker; on older versions set `DOCKER_BUILDKIT=1`.

## Learning objectives

By the end of this module you will be able to:

- Read and write the core **Dockerfile instructions** (`FROM`, `RUN`, `COPY`/`ADD`,
  `ENV`, `WORKDIR`, `USER`, `EXPOSE`, `ARG`, `CMD` vs `ENTRYPOINT`).
- Explain **image layers and the build cache**, and order instructions so a code edit
  doesn't re-download every dependency.
- Use **multi-stage builds** to compile in a fat toolchain and ship a slim runtime,
  cutting image size by an order of magnitude.
- Keep secrets out of layers with **BuildKit build secrets** and shrink the context
  with **`.dockerignore`**.
- Choose a **base image** (`debian:slim`, `alpine`, distroless, `scratch`) with reasons,
  trading size against compatibility and debuggability.

---

## 1. Concept

### What `docker build` does

`docker build` turns a **Dockerfile** — an ordered list of instructions — into an
**OCI image** (Module 02.1): read-only layers plus a JSON config. Each instruction
that touches the filesystem adds **one layer**, run top to bottom; the builder caches
each so unchanged steps are reused next time.

### The instructions that matter

- **`FROM`** — the base every layer stacks on (`FROM scratch` is nothing); a file may
  have **multiple** `FROM`s (multi-stage, below).
- **`RUN`** — run a command at **build time**, committing the result as a layer.
- **`COPY` vs `ADD`** — both copy local files; **prefer `COPY`**. `ADD` also fetches URLs
  and auto-extracts tarballs — reserve it for tar extraction.
- **`WORKDIR`** — sets and creates the directory for later steps (not `RUN cd …`, which
  doesn't persist).
- **`ENV`** persists **into the running container**; **`ARG`** is **build-time-only**
  (below).
- **`EXPOSE`** — documentation only; records a port but doesn't publish it.
- **`USER`** — the UID the container runs as; default **root**, so production images drop
  to non-root (Module 02.5).
- **`CMD` vs `ENTRYPOINT`** — `ENTRYPOINT` is the executable, `CMD` its default arguments
  (overridden by `docker run` args). Use the **exec form** (`["bin","arg"]`): the shell
  form runs under `/bin/sh -c`, so your app isn't PID 1 and never gets `SIGTERM`
  (Module 02.1).

### Layers and the build cache

Each layer is **content-addressed** by its inputs. On rebuild the builder reuses a
cached layer only if its inputs are unchanged; the **first** changed instruction
**invalidates every layer after it**. The cache is a **prefix, not a set**, which
dictates order:

```dockerfile
# Cache-hostile: any source edit re-runs the slow dependency install.
FROM python:3.12-slim
WORKDIR /app
COPY . .                       # app code AND manifests copied together
RUN pip install -r requirements.txt
```

```dockerfile
# Cache-friendly: deps reinstall only when requirements.txt changes.
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt ./       # changes rarely -> stays cached
RUN pip install -r requirements.txt
COPY . .                       # changes often -> only this layer rebuilds
```

Editing one line of code changes the `COPY . .` inputs, invalidating the `pip install`
after it — **every build re-downloads every dependency**. Copy the manifest **first** and
that layer stays cached until dependencies change. This
**copy-dependencies-before-source** pattern applies to every ecosystem (`package.json`,
`go.mod`, `Cargo.toml`).

### Multi-stage builds: build fat, ship thin

Compiling needs a toolchain the **running** app never uses; shipping it bloats the image
and widens the attack surface. A **multi-stage build** builds in one stage and copies
only the artifact into a second, minimal one:

```dockerfile
FROM golang:1.22 AS build          # stage 1: the whole toolchain (~800 MB)
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /bin/app .

FROM gcr.io/distroless/static-debian12:nonroot   # stage 2: clean, minimal
COPY --from=build /bin/app /bin/app
USER nonroot:nonroot
ENTRYPOINT ["/bin/app"]
```

`COPY --from=build` takes just the binary; the toolchain, source, and intermediates are
**left behind** — how a 900 MB build becomes a ~15 MB image.

### ARG vs ENV, and never bake secrets

`ARG` is **build-time** (set with `--build-arg`, absent from the running container);
`ENV` is **baked into the image** and visible to the process and to `docker inspect`.
Neither is safe for a secret: `docker history --no-trunc <image>` prints every value, and
a value written to a layer **stays in history** even after a later layer deletes it
(additive). Use a **BuildKit build secret**, mounted into one `RUN` as a tmpfs file that
never lands in a layer:

```dockerfile
# syntax=docker/dockerfile:1
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm ci   # the .npmrc exists only for this command, never in a layer
```

```bash
docker build --secret id=npmrc,src=$HOME/.npmrc -t app .
```

### `.dockerignore`: shrink the build context

Before building, Docker sends the **build context** (by default the whole directory) to
the builder; `.dockerignore` excludes paths from it — `.gitignore`, for builds:

```text
.git
node_modules
*.md
Dockerfile*
**/*.log
.env
```

It helps three ways: **speed** (skip `.git/` and `node_modules/`), **security** (a stray
`.env` or key can't be swept in by `COPY . .`), and **caching** (files outside the
context can't bust a `COPY` layer).

### Choosing a base image

The base sets your size floor, your libc, and most of your CVE count:

- **`debian:12-slim`** — glibc, `apt`, a shell; ~30–80 MB. The safe default: broad
  compatibility, easy to debug.
- **`alpine`** — ~5 MB, but **musl** libc, not glibc. Great for static Go, but a source
  of subtle bugs for glibc-linked languages (DNS, threading) and *slower* Python/C
  builds. Adopt it deliberately.
- **distroless** (`gcr.io/distroless/*`) — runtime and libraries only: **no shell, no
  package manager**. Tiny surface and few/zero CVEs, but no `exec … sh` to debug.
- **`scratch`** — empty; only a **fully static** binary runs. The smallest image.

### Size reduction and BuildKit

- **Combine `RUN`s and clean in the same layer** — a later `RUN rm` can't shrink an
  earlier layer, so install and clean together:

  ```dockerfile
  RUN apt-get update \
   && apt-get install -y --no-install-recommends ca-certificates \
   && rm -rf /var/lib/apt/lists/*
  ```

- **Strip binaries** — Go `-ldflags="-s -w"` plus `CGO_ENABLED=0` yields a small, static
  binary for `scratch`/distroless.
- **BuildKit** (default in modern Docker; else `DOCKER_BUILDKIT=1` or `docker buildx`)
  adds **parallel stages**, **cache mounts** (`RUN --mount=type=cache`) that persist
  across builds, **secret and SSH mounts**, and **registry cache**
  (`--cache-to`/`--cache-from`) so CI runners share layers (Module 02.7).

---

## 2. Why it matters for platform engineering

The Dockerfile is the **interface between "my code" and "a deployable artifact,"** and on
a platform you own it for every team:

- **Build time is developer time.** A cache-hostile Dockerfile turns a one-line change
  into a multi-minute rebuild on every push; correct ordering in a template buys that
  back hundreds of times a day.
- **Image size is money and risk.** Every megabyte is pulled, stored, and scanned on
  every release — 900 MB → 15 MB cuts latency, storage, and the CVE count.
- **Base image choice is a fleet-wide security decision** that shrinks the attack
  surface of everything you ship.
- **Secrets in layers are breaches.** BuildKit secrets make "don't bake secrets" the
  default, not a rule people forget.

When a build is slow, bloated, or leaking, the fix is almost always one of the patterns
above.

---

## 3. Mental model

Picture an image as a **stack of diffs with a cache that behaves like a prefix**: the
builder reuses cached layers up to the first changed instruction, then rebuilds the
rest.

```text
Dockerfile instruction        ->  layer (content-addressed)        changes?  cache
------------------------------------------------------------------------------------
FROM golang:1.22              ->  [base: compiler, libc, shell]    ~never    pull 1x
WORKDIR /src                  ->  (metadata, ~0 B)                 ~never    ^ reuse
COPY go.mod go.sum ./         ->  [dependency manifest]            rarely    ^ reuse
RUN go mod download           ->  [downloaded modules]             rarely    ^ reuse
COPY . .                      ->  [your source]                    OFTEN  -- v busts
RUN go build -o /bin/app      ->  [compiled binary]                OFTEN     v rebuild
------------------------------------------------------------------------------------
      order by change frequency; then a multi-stage build copies only [/bin/app]
      into a clean, minimal runtime, so the toolchain layers never ship
```

Three sentences to keep for a year:

- An image is **layers**; the cache is a **prefix** — the first changed instruction
  rebuilds everything after it, so **order by change frequency**.
- **Build fat, ship thin:** compile in a toolchain stage, copy only the artifact into a
  minimal runtime.
- **Layers are additive and public:** a later `rm` can't remove a secret from an earlier
  layer, so never write one into a layer.

---

## 4. Minimal implementation

Start with the problem — the Dockerfile most people write first: one stage, copy
everything, build.

```dockerfile
# naive.Dockerfile - correct, but slow to rebuild and huge to ship
FROM golang:1.22
WORKDIR /src
COPY . .
RUN go build -o /bin/app .
CMD ["/bin/app"]
```

```bash
docker build -f naive.Dockerfile -t app:naive .
docker images app:naive          # ~800 MB - it ships the whole Go toolchain
```

Two problems. **Caching:** `COPY . .` precedes the build, so any edit re-runs it (the
dependency download sits here too). **Size:** the image carries a compiler the binary
never needs. Both are fixed by ordering dependencies first *and* splitting into stages:

```dockerfile
FROM golang:1.22 AS build
WORKDIR /src
COPY go.mod ./            # deps first -> cached until go.mod changes
RUN go mod download
COPY . .                  # source -> changes often, rebuilds only from here
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /bin/app .

FROM scratch              # empty base -> only the static binary ships
COPY --from=build /bin/app /bin/app
ENTRYPOINT ["/bin/app"]
```

```bash
docker build -t app:tiny .
docker images app:tiny           # ~10-15 MB - ~50x smaller
```

You didn't reach for a tool; you reordered instructions and split the build. Understand
the layer-and-cache problem, then apply **order by change frequency** and **build fat /
ship thin**. The lab measures the payoff.

---

## 5. Hands-on lab

You'll build the **same Go web service three ways** — naive single-stage, multi-stage on
`debian-slim`, and distroless — then **measure and compare** size, build time, package
count, shell presence, and CVE count. The numbers make the patterns above concrete.

➡️ **[Start the lab: Build one app three ways](./lab/README.md)**

---

## 6. Production considerations

- **Pin base images by digest.** `FROM debian:12-slim` is a moving tag; pin `@sha256:…`
  and bump it deliberately with Renovate/Dependabot.
- **Run as non-root, and prove it.** Set `USER` with a numeric UID so Kubernetes
  `runAsNonRoot` can verify it; distroless `:nonroot` makes it the default.
- **Scan in CI with a budget.** Fail the build on new HIGH/CRITICAL CVEs (Trivy/Grype);
  smaller bases keep this green.
- **Share cache across CI runners** with BuildKit registry cache
  (`--cache-to`/`--cache-from`) so ephemeral runners don't cold-build.
- **Ship a `.dockerignore` in every template** so teams don't send `.git/` or secrets
  into the build context by default.
- **Emit an SBOM and provenance** (`docker buildx … --sbom --provenance`) for
  supply-chain integrity (Module 02.7).

## 7. Common mistakes

- **Copying source before dependencies.** — The install layer sits after `COPY . .`, so
  every edit re-runs it. *Fix:* copy the manifest and install **first**.
- **Shipping the build toolchain.** — A single-stage image carries compilers the app
  never runs. *Fix:* multi-stage; copy only the artifact into a minimal runtime.
- **Baking secrets into layers.** — A `--build-arg` token, or a file written then
  deleted, still lives in `docker history`. *Fix:* `RUN --mount=type=secret`; never put
  a secret in `ARG`/`ENV`.
- **`rm`-ing in a later layer to save space.** — It can't shrink the earlier layer that
  added the files. *Fix:* install and clean in the **same** `RUN`.
- **Shell-form `CMD`/`ENTRYPOINT`.** — `CMD app` runs under `/bin/sh -c`, so it isn't PID
  1 and misses `SIGTERM`. *Fix:* use the exec form, `CMD ["app"]`.
- **No `.dockerignore`, or `alpine` by reflex.** — A missing ignore file leaks `.git/`
  and secrets; musl breaks some glibc assumptions. *Fix:* add a `.dockerignore`, and
  default to `debian:slim`/distroless — alpine only for static binaries.

## 8. Assessment

**Knowledge checks**

1. Why does instruction **order** change build speed, and what is the
   "copy-dependencies-before-source" pattern?
2. What does a **multi-stage build** let you avoid shipping, and how does
   `COPY --from=…` make that possible?
3. Give two reasons a secret passed via `--build-arg` is unsafe, and the correct
   BuildKit alternative.
4. `CMD` vs `ENTRYPOINT`, and exec vs shell form — what does each control, and why does
   the form affect signal handling?
5. Contrast `debian:slim`, `alpine`, distroless, and `scratch` on size, libc, and
   debuggability.

**Concept exercise**

> Explain **image layering and the build cache** to a new teammate **without using the
> words "Docker" or "Dockerfile."** Say why the order of steps decides how much work a
> rebuild repeats.

**Trade-off exercise**

> Your service is a compiled Go binary that must ship with the smallest attack surface,
> but on-call engineers want to debug a running container. Argue for **alpine vs
> distroless vs debian-slim** as the runtime base, and state the trade-off.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** The cache is a **prefix** — reused until the first changed instruction, then
  everything after rebuilds. Installing dependencies **before** copying source keeps a
  code edit from invalidating the slow install layer.
- **Q2:** The **build toolchain** (compilers, headers, source). A later `FROM` starts
  clean and `COPY --from=build` pulls only the finished artifact across.
- **Q3:** Build args appear in `docker history` and persist in layers even after a delete
  (additive), so anyone who can pull reads the secret. Use `RUN --mount=type=secret`.
- **Q4:** `ENTRYPOINT` is the executable, `CMD` the default args. **Exec form** runs as
  PID 1 so it gets `SIGTERM`; **shell form** (`/bin/sh -c "app"`) makes it a child that
  misses signals.
- **Q5:** `debian:slim` — glibc + shell, easiest to debug. `alpine` — ~5 MB, musl
  caveats. distroless — no shell, tiny surface, hard to debug. `scratch` — empty, static
  only, smallest.
- **Trade-off:** distroless/`scratch` give the smallest surface and near-zero CVEs but no
  shell; **debian-slim** keeps a shell for on-call debugging at more size and CVEs;
  **alpine** is small with a shell but musl can shift behaviour. A common answer: ship
  distroless and debug with a separate image or `kubectl debug`.

</details>

---

## 9. Further reading

- Docker — [Dockerfile reference](https://docs.docker.com/reference/dockerfile/) and
  [building best practices](https://docs.docker.com/build/building/best-practices/)
- Docker — [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
  and [build secrets](https://docs.docker.com/build/building/secrets/)
- Docker — [BuildKit](https://docs.docker.com/build/buildkit/) and the
  [build context / `.dockerignore`](https://docs.docker.com/build/concepts/context/)
- GoogleContainerTools — [distroless base images](https://github.com/GoogleContainerTools/distroless)
- Itamar Turner-Trauring — [“Alpine makes Python Docker builds slower”](https://pythonspeed.com/articles/alpine-docker-python/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [02.1 — Container Fundamentals](../01-container-fundamentals/)
· _Next:_ [02.3 — Container Networking →](../03-container-networking/)
