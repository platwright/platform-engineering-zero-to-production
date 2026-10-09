# Module 02.5 — Container Security

> A container is only as safe as the process inside it and the privileges you give
> it. By default, containers run as **root**, with a **writable** filesystem and a
> broad set of Linux capabilities — a generous attack surface. This module turns
> that default on its head: non-root, read-only, least-privilege, scanned, and with
> no secrets baked into the image. These are the defaults a platform bakes into
> every golden path.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** [Module 02.2](../02-dockerfile-and-image-building/), Docker, and
[Trivy](https://trivy.dev/latest/getting-started/installation/) (installed in the lab).

## Learning objectives

By the end of this module you will be able to:

- Explain why **running as non-root** is the single most important container control.
- Harden a container with a **read-only root filesystem**, **dropped capabilities**,
  **`no-new-privileges`**, and a **seccomp** profile.
- Choose **distroless/scratch** base images to shrink the attack surface.
- Scan an image for vulnerabilities with **Trivy** and read the result.
- State why **secrets must never be baked into image layers**.

---

## 1. Concept

### The default container is over-privileged

Recall Module 02.1: a container is just a Linux process with namespaces and cgroups.
Nothing about that makes it *secure* — isolation is not the same as hardening. Out of
the box, a typical container:

- runs as **UID 0 (root)** inside its namespaces,
- has a **writable** root filesystem,
- holds a **default set of Linux capabilities** (≈14 of them), and
- can acquire **new privileges** via setuid binaries.

If an attacker compromises the process, each of those is a lever. Container escapes
are rarer than in-container damage, but "root in the container" is still a much worse
starting position for an attacker than "an unprivileged user who can't write
anything or add privileges." Defense in depth means removing every lever you don't
need.

### The hardening checklist

Five controls do most of the work. Think of them as peeling away privilege you were
never using:

```text
1. Run as NON-ROOT            runAsNonRoot / USER / --user 10001
2. READ-ONLY root filesystem  --read-only (+ tmpfs for the few writable paths)
3. DROP all capabilities      --cap-drop ALL (add back only what you truly need)
4. NO new privileges          --security-opt no-new-privileges
5. A restrictive SECCOMP      --security-opt seccomp=... (RuntimeDefault is a floor)
```

- **Non-root.** The highest-leverage control. Most images don't need root; they need
  to run one binary and bind one high port. Run as an unprivileged UID.
- **Read-only root filesystem.** If the process can't write to its own filesystem, it
  can't drop a web shell, tamper with binaries, or persist. Mount small writable
  `tmpfs` or volumes for the few paths that genuinely need to be written (caches,
  `/tmp`, pid files).
- **Drop capabilities.** Linux capabilities split root's power into units
  (`NET_ADMIN`, `SYS_ADMIN`, `NET_BIND_SERVICE`, …). Drop **ALL**, then add back only
  what the app needs (usually nothing). Binding a port below 1024? Use a high port
  instead of granting `NET_BIND_SERVICE`.
- **No new privileges.** Prevents a process from gaining more privileges than its
  parent through setuid/setgid binaries — closes a common escalation path.
- **Seccomp.** Filters which **syscalls** the process can make. The container
  runtime's `RuntimeDefault` profile blocks dozens of dangerous syscalls and is a
  sensible floor; tighter custom profiles go further.

> **AppArmor / SELinux** add mandatory access control on top (confining what files
> and operations a process may touch). `RuntimeDefault`/distro profiles are a good
> baseline; custom profiles are an advanced control.

### Minimize the base image

You can't exploit a shell that isn't there. A smaller base image has fewer binaries,
fewer libraries, and therefore fewer CVEs and fewer tools for an attacker to pivot
with:

```text
debian:12        ~120 MB   full distro, shell, package manager   large attack surface
alpine:3         ~7 MB     tiny distro, busybox shell             small
distroless       ~2–20 MB  your app + runtime, NO shell/pkg mgr   very small
scratch          0 MB      literally empty; static binary only    minimal
```

**Distroless** images (just your app and its runtime dependencies — no shell, no
package manager) and **scratch** (empty; for fully static binaries) dramatically cut
the attack surface. The trade-off: no shell means you debug with ephemeral debug
containers instead of `docker exec ... sh` — a worthwhile exchange in production.

### Scan what you ship

Even a minimal image can ship a vulnerable library. **Image scanning** (Trivy is the
course default) compares the packages in an image against vulnerability databases and
reports CVEs by severity. The platform move is to **scan in CI and block on critical
findings** (you'll wire that gate in Phase 5), so vulnerable images never reach
production.

### Never bake secrets into layers

A Docker image is a stack of layers, and **every layer is permanent and inspectable**
(`docker history`, `docker save`, any registry pull). A secret `COPY`ed or `ENV`'d in
one layer and "removed" in a later layer is **still there** in the earlier layer.
Rules:

- Never `COPY` a key/token or put a secret in `ENV` or `ARG` in a Dockerfile.
- Use **build secrets** (`RUN --mount=type=secret`) for build-time credentials — they
  don't persist in the image.
- Inject **runtime** secrets via the orchestrator (you'll use the External Secrets
  Operator in Phase 13), never via the image.

---

## 2. Why it matters for platform engineering

Security is structural, not a bolt-on (a course principle). A platform team doesn't
ask each product team to remember these controls — it **bakes them into the golden
path** so every service is hardened by default:

- The platform's base images are distroless and non-root.
- The service template ships a hardened security context.
- CI scans and blocks on critical CVEs.
- Admission policy (Kyverno, Phase 13) *rejects* workloads that aren't hardened, so
  "I forgot `runAsNonRoot`" can't reach production.

That's the difference between hoping every team does the right thing and making the
right thing the only thing that ships. The habits you build here on Docker map
directly onto Kubernetes `securityContext` and Pod Security Standards (Phase 3 and
the Project 1 foundation).

## 3. Mental model

```text
          Attack surface of a container
          ─────────────────────────────
   privilege │ root ───────────────► non-root (10001)
   filesystem│ writable ───────────► read-only + small tmpfs
 capabilities│ ~14 caps ───────────► drop ALL
  escalation │ allowed ────────────► no-new-privileges
    syscalls │ most allowed ───────► seccomp RuntimeDefault (or tighter)
   base image│ full distro + shell ► distroless / scratch (no shell)
       CVEs  │ unknown ────────────► scanned, gated in CI
     secrets │ in layers ──────────► never in the image; injected at runtime

   Every arrow removes a lever an attacker could pull.
```

One sentence: **run the least-privileged process, on the smallest base, scanned, with
no secrets inside — by default.**

## 4. Minimal implementation

Take an ordinary container and remove privilege, one flag at a time. Each flag maps
to a control above:

```bash
docker run --rm \
  --user 10001:10001 \              # non-root
  --read-only \                     # read-only root filesystem
  --tmpfs /tmp \                    # the one writable path the app needs
  --cap-drop ALL \                  # no Linux capabilities
  --security-opt no-new-privileges \ # cannot escalate
  --security-opt seccomp=default \  # restrict syscalls (RuntimeDefault)
  myapp:latest
```

That single command is the whole lesson in miniature: it's the same process, with
every unnecessary privilege taken away. In a Dockerfile, you bake the same intent in:

```dockerfile
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /app /app
USER nonroot        # 65532, not root
ENTRYPOINT ["/app"]
```

You'll build exactly this, scan it, and run it hardened in the lab.

## 5. Hands-on lab

Scan a common image and a distroless image with Trivy to *see* the attack-surface
difference, then build and run a hardened, non-root, read-only container — and watch
the hardening stop things that an unhardened container would allow.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **Enforce, don't request.** In Kubernetes, make non-root/read-only/dropped-caps
  **mandatory** via Pod Security Admission and Kyverno (Phase 13), not optional.
- **Scan continuously, gate in CI.** New CVEs are published daily; an image that was
  clean last week may not be today. Re-scan running images and block builds on
  critical findings.
- **Pin and rebuild base images.** Track your base image's digest and rebuild/patch
  on CVE disclosures — minimal bases make this cheap.
- **Debug without a shell.** Distroless images have no shell by design; use ephemeral
  debug containers (`kubectl debug`) in production rather than shipping a shell.
- **Generate and keep an SBOM.** Know exactly what's in each image so you can answer
  "are we affected by CVE-X?" in minutes, not days (Module 02.7, Phase 13).
- **Secrets at runtime only.** Inject via the platform's secret mechanism; never via
  image layers, `ENV`, or `ARG`.

## 7. Common mistakes

- **Running as root "because it's easier."** — It usually works, and it's the worst
  default. *Fix:* set a non-root `USER`/`--user`; fix file permissions, don't grant
  root.
- **Granting `NET_BIND_SERVICE` to bind port 80.** — Adds privilege you can avoid.
  *Fix:* listen on a high port (8080) and map it; keep `--cap-drop ALL`.
- **`--read-only` with no writable mount, so the app crashes.** — Then disabling
  read-only entirely. *Fix:* keep read-only and add a small `tmpfs`/volume for the
  exact paths that need writes.
- **"Removing" a secret in a later layer.** — The secret still lives in the earlier
  layer and in history. *Fix:* never add it; use build secrets and runtime injection.
- **Treating a passing scan as "secure."** — Scanning finds *known* CVEs in packages,
  not logic flaws or misconfiguration. *Fix:* combine scanning with hardening, least
  privilege, and policy.
- **Shipping a full distro base for a static binary.** — Hundreds of MB and dozens of
  CVEs you never use. *Fix:* distroless or scratch.

## 8. Assessment

**Knowledge checks**

1. Why is running as non-root the highest-leverage container security control?
2. What does `--cap-drop ALL` do, and how do you then let an app bind a low port?
3. Why does "removing" a secret in a later Dockerfile layer fail to actually remove
   it?
4. What is a **distroless** image, and what do you give up by using one?
5. What does an image scanner like Trivy detect — and what does it *not*?

**Concept exercise**

> Explain how to make a container "least privilege" **without using the word
> "security."** Describe, in plain terms, what you take away and why it's safe.

**Trade-off exercise**

> A team's app needs to write temporary files and currently runs as root with a
> writable filesystem. How do you move it to non-root + read-only without breaking
> it, and what would you check before enforcing it in production?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Most in-container damage and many escalation paths assume root; an
  unprivileged user can't write system paths, add privileges, or use most dangerous
  syscalls, so compromising the process yields far less.
- **Q2:** It removes all Linux capabilities (the split-up pieces of root's power). To
  bind a privileged port without `NET_BIND_SERVICE`, listen on a high port (e.g.
  8080) and publish/route it externally.
- **Q3:** Images are immutable stacked layers; a secret added in one layer persists in
  that layer (and in `docker history`/`save`) even if a later layer deletes the file.
- **Q4:** An image containing only your app and its runtime deps — no shell or package
  manager. You give up in-container debugging via `exec`/shell; you debug with
  ephemeral containers instead.
- **Q5:** It detects *known* vulnerabilities (CVEs) in OS/app packages and some
  misconfigurations; it does **not** find business-logic flaws, zero-days, or runtime
  behavior.
- **Trade-off:** Add a writable `tmpfs`/volume for the temp paths, set a non-root
  `USER` and fix ownership of those paths, then enable `--read-only`. Before
  enforcing: test that the app's writes all target the mounted paths, run its test
  suite, and watch logs for permission errors; roll out in `audit`/`warn` mode first.

</details>

## 9. Further reading

- Trivy — [documentation](https://trivy.dev/) and [vulnerability scanning](https://trivy.dev/latest/docs/scanner/vulnerability/)
- Google — [Distroless container images](https://github.com/GoogleContainerTools/distroless)
- Docker — [Run the Docker daemon / containers securely](https://docs.docker.com/engine/security/)
- Linux — [capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html) and [seccomp](https://docs.docker.com/engine/security/seccomp/)
- Kubernetes — [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [02.4 — Container Storage](../04-container-storage/) · _Next:_ [02.6 — Container Registries](../06-container-registries/)
