# Lab — Scan and harden a container

> You'll *see* the attack-surface difference by scanning a common image and a
> distroless one with Trivy, then build and run a hardened, non-root, read-only
> container — and watch the hardening flags stop things an unhardened container
> allows. Everything runs locally and free.

**Estimated time:** ~40–60 minutes
**Type:** Build / security
**Deliverable:** A hardened image you built, running non-root under a security
context, plus a Trivy scan report comparing it to a stock image.

## Objectives

- Scan images with Trivy and read the severity breakdown.
- Build a hardened, non-root, distroless image.
- Observe the effect of `--read-only`, `--user`, and `--cap-drop` directly.

## Prerequisites

- Docker installed and working. See
  [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md).
- [Trivy](https://trivy.dev/latest/getting-started/installation/) installed
  (`trivy --version`).
- Linux, macOS, or **WSL2** on Windows. No cost — all local.
- Starter files in this folder: [`main.go`](./main.go), [`go.mod`](./go.mod),
  [`Dockerfile.hardened`](./Dockerfile.hardened).

## Steps

1. **Scan a common image and read the result.**

   ```bash
   trivy image --severity HIGH,CRITICAL nginx:latest
   ```

   Note the count of HIGH/CRITICAL vulnerabilities. A full distro base ships a lot of
   packages you never use — each one a potential CVE.

2. **Scan a distroless image for comparison.**

   ```bash
   trivy image --severity HIGH,CRITICAL gcr.io/distroless/static-debian12:nonroot
   ```

   Far fewer (often zero) findings — there's almost nothing in the image to be
   vulnerable. Smaller base, smaller attack surface.

3. **Build your own hardened image** (static Go binary on distroless nonroot):

   ```bash
   docker build -f Dockerfile.hardened -t hardened-app:1.0 .
   docker image ls hardened-app:1.0          # note how small it is
   trivy image --severity HIGH,CRITICAL hardened-app:1.0
   ```

4. **Run it hardened and prove it's non-root.**

   ```bash
   docker run -d --name hardened -p 8080:8080 \
     --read-only \
     --cap-drop ALL \
     --security-opt no-new-privileges \
     hardened-app:1.0

   curl -s http://localhost:8080/          # -> ok (uid=65532)  (NOT uid=0)
   docker rm -f hardened
   ```

   The response shows the app runs as UID 65532 — not root — with every capability
   dropped, no ability to escalate, and a read-only root filesystem. It didn't need
   any of that privilege to serve HTTP.

5. **See each control take effect** (using `alpine`, which has a shell to test with):

   ```bash
   # Default: root, writable filesystem — the write succeeds
   docker run --rm alpine sh -c 'id; touch /evil && echo "wrote /evil (root, writable)"'

   # Read-only root filesystem — the same write now FAILS
   docker run --rm --read-only alpine sh -c 'touch /evil' \
     || echo "read-only FS: write denied (good)"

   # Non-root user — now running as uid 10001, not root
   docker run --rm --user 10001:10001 alpine id

   # Drop all capabilities and still run fine for a normal workload
   docker run --rm --cap-drop ALL --user 10001:10001 alpine sh -c 'echo "no caps, still works"'
   ```

## Expected result

- `nginx:latest` shows noticeably more HIGH/CRITICAL CVEs than distroless.
- Your `hardened-app:1.0` is tiny and scans clean (or near-clean).
- The hardened container responds with `uid=65532` (non-root).
- `--read-only` blocks the write that succeeds without it; `--user` changes the UID.

## Cleanup

> No cloud resources, but remove the local images and any containers.

```bash
docker rm -f hardened 2>/dev/null || true
docker rmi hardened-app:1.0 nginx:latest gcr.io/distroless/static-debian12:nonroot alpine 2>/dev/null || true
```

## Reflection

- Which single control (non-root, read-only, drop-caps) would you enforce first
  across every team, and why?
- Your hardened image has no shell. How would you debug it when it misbehaves in
  production (hint: ephemeral debug containers, Phase 3)?
- Scanning found *known* CVEs. What classes of problem does scanning **not** catch?

## Stretch goals (optional)

- Add `--security-opt seccomp=unconfined` vs the default and read about which
  syscalls the default profile blocks.
- Fail a build on critical CVEs locally: `trivy image --exit-code 1 --severity
  CRITICAL hardened-app:1.0` and observe the non-zero exit — the same gate you'll put
  in CI in Phase 5.
