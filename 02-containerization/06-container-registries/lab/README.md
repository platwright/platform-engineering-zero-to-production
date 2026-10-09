# Lab — Promote an image by immutable digest

> You'll run a local registry, push an image, and *prove* the central idea: a **tag**
> can be moved to new bytes, but a **digest** can't. Then you'll promote the
> known-good image from dev to prod **by digest**, so the exact bytes you tested are
> the ones that ship. All local, all free.

**Estimated time:** ~30–45 minutes
**Type:** Build / discovery
**Deliverable:** A `:prod` image that points at the *same digest* you built and
tested as `:dev`, with notes proving a moved tag did not change it.

## Objectives

- Run a local registry and push/pull by tag and by digest.
- Demonstrate tag mutability vs digest immutability.
- Promote an image dev → prod by digest (same bytes, no rebuild).

## Prerequisites

- Docker installed and working. See
  [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md).
- Starter file in this folder: [`Dockerfile`](./Dockerfile). No cost — all local.

## Steps

1. **Start a local registry.**

   ```bash
   docker run -d -p 5000:5000 --name registry registry:2
   ```

2. **Build and push the image as `:dev`, and capture its digest.**

   ```bash
   docker build -t localhost:5000/app:dev .
   docker push localhost:5000/app:dev

   DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' localhost:5000/app:dev)
   echo "built and tested: $DIGEST"     # localhost:5000/app@sha256:...
   docker run --rm localhost:5000/app:dev   # prints: v1
   ```

3. **Move the tag to different content** (edit the Dockerfile, change `v1` → `v2`):

   ```bash
   sed -i 's/echo "v1"/echo "v2"/' Dockerfile   # (or edit by hand)
   docker build -t localhost:5000/app:dev .
   docker push localhost:5000/app:dev
   docker run --rm localhost:5000/app:dev       # prints: v2  — the TAG moved!
   ```

   The `:dev` tag now points at *different bytes*. If prod followed the tag, it would
   silently change too. This is the "the image changed but the tag didn't" incident.

4. **Prove the digest is immutable.**

   ```bash
   docker pull "$DIGEST"
   docker run --rm "$DIGEST"                     # STILL prints: v1
   ```

   The digest from step 2 refers to the exact original bytes, forever — regardless of
   where the `:dev` tag now points.

5. **Promote dev → prod by digest** (ship the bytes you tested, not whatever `:dev`
   points to now):

   ```bash
   docker tag "$DIGEST" localhost:5000/app:prod
   docker push localhost:5000/app:prod
   docker run --rm localhost:5000/app:prod       # prints: v1  — the tested bytes
   ```

6. **Confirm `:prod` and your tested digest are the same content.**

   ```bash
   docker inspect --format='{{index .RepoDigests 0}}' localhost:5000/app:prod
   echo "$DIGEST"
   # the sha256 values match — prod is the exact image you tested
   ```

## Expected result

- `:dev` prints `v2` after step 3 (the tag moved), but the **digest** from step 2
  still prints `v1` (immutable).
- `:prod` prints `v1` — you promoted the tested bytes by digest, not the drifted tag.

## Cleanup

```bash
docker rm -f registry 2>/dev/null || true
docker rmi localhost:5000/app:dev localhost:5000/app:prod "$DIGEST" alpine:3.20 2>/dev/null || true
# restore the Dockerfile if you changed it
sed -i 's/echo "v2"/echo "v1"/' Dockerfile 2>/dev/null || true
```

## Reflection

- Step 3 is exactly how "`:latest` changed under us" incidents happen. How does
  deploying by digest prevent a whole class of these?
- In a real pipeline, *where* would the digest be recorded so the next environment
  deploys the right one (hint: CI output → GitOps config, Phases 5 and 7)?
- "Promotion" here was adding a `:prod` tag to a digest. What else might promotion
  check first (scan results, signatures, approvals)?

## Stretch goals (optional)

- Inspect the image without Docker using `crane`:
  `crane digest localhost:5000/app:dev` and `crane manifest localhost:5000/app:prod`.
- Push a non-image **OCI artifact** (e.g. a text file) with
  [ORAS](https://oras.land/) to see that registries store more than images.
