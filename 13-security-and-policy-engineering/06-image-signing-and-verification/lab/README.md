# Lab — Sign an image and block unsigned images at admission

> You'll sign a container image with Cosign, verify it, then apply a Kyverno
> `verifyImages` policy so the cluster **runs the signed image and rejects an unsigned
> one**. This is the local, free version of the Pass-2 enforcement Project 2 ships —
> here with a local key pair instead of keyless OIDC.

**Estimated time:** ~50–70 minutes
**Type:** Build
**Deliverable:** A signed image, a `verifyImages` ClusterPolicy keyed to your public
key, and proof that a signed pod is admitted while an unsigned one is rejected.

## Objectives

- Generate a Cosign key pair and sign an image by digest.
- Verify a signature locally and reason about what it proves.
- Enforce signature verification at admission with Kyverno `verifyImages`.
- Prove the guardrail: signed admitted, unsigned rejected.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- [Helm](https://helm.sh/docs/intro/install/) and [Cosign](https://docs.sigstore.dev/cosign/system_config/installation/).
- Internet access (the lab pushes to the free, anonymous
  [`ttl.sh`](https://ttl.sh/) ephemeral registry — images expire in 1 hour, no account
  needed). `python3` (to inject your key into the policy).
- Starter files here: [`cosign-commands.sh`](./cosign-commands.sh),
  [`kyverno-verify-images.yaml`](./kyverno-verify-images.yaml),
  [`inject-key.py`](./inject-key.py).

> **Local vs keyless.** This lab uses a **local key pair** so it needs no accounts.
> Production should prefer **keyless** signing (OIDC) — the policy's keyless variant is
> included (commented) and mirrors
> [Project 2's Pass-2 policy](../../../09-platform-project-02/gitops-platform/config-repo/platform/pass2/kyverno-verify-images.yaml).

## Steps

1. **Create a cluster and install Kyverno.**

   ```bash
   kind create cluster --name pe-sign
   helm repo add kyverno https://kyverno.github.io/kyverno/ && helm repo update
   helm install kyverno kyverno/kyverno -n kyverno --create-namespace
   kubectl -n kyverno rollout status deploy/kyverno-admission-controller
   ```

2. **Sign an image.** Run the helper, which generates a key pair, builds a tiny image,
   pushes it to `ttl.sh`, and signs it by digest:

   ```bash
   bash cosign-commands.sh
   ```

   It writes your signed reference to `signed-image.txt` and leaves `cosign.key` /
   `cosign.pub` in the directory. Read the final `cosign verify` output — that's the
   cryptographic "yes, this key signed exactly these bytes."

3. **Build the enforced policy from your public key.** The starter policy has a
   `__COSIGN_PUB__` placeholder; inject your real key into it:

   ```bash
   python3 inject-key.py
   cat verify-images.enforced.yaml | head -n 20
   ```

4. **Apply the policy.** It requires a valid signature for any `ttl.sh/*` image and
   pins the pull to the verified digest:

   ```bash
   kubectl apply -f verify-images.enforced.yaml
   kubectl get clusterpolicy verify-image-signatures
   ```

5. **Deploy the SIGNED image — it is admitted.**

   ```bash
   SIGNED="$(cat signed-image.txt)"
   kubectl run signed-app --image="$SIGNED" --restart=Never
   kubectl get pod signed-app       # Running — signature verified, image pinned to digest
   ```

6. **Push an UNSIGNED image and watch it get rejected.** Same registry, no signature:

   ```bash
   UNSIGNED="ttl.sh/pe-unsigned-$(cat /proc/sys/kernel/random/uuid):1h"
   docker pull busybox:1.37
   docker tag busybox:1.37 "$UNSIGNED"
   docker push "$UNSIGNED"
   kubectl run unsigned-app --image="$UNSIGNED" --restart=Never   # ← REJECTED at admission
   ```

   Read the error: Kyverno refuses the pod because the image has no signature matching
   your key. That is the supply-chain guardrail — no valid signature, no run.

7. **(Optional, needs accounts) Try the keyless path.** With a GitHub/registry account
   you can sign keyless (`cosign sign --yes <ghcr-ref>`) and switch the policy to the
   commented `keyless` attestor block, pinning `issuer` and `subject` to your pipeline
   identity — exactly as Project 2's Pass-2 policy does. This needs an OIDC login and a
   registry you can push to, so it is **optional** and may incur cost.

## Expected result

- `signed-app` (signed `ttl.sh` image) is **admitted** and runs.
- `unsigned-app` (unsigned `ttl.sh` image) is **rejected** at admission with a Kyverno
  message about a missing/invalid signature.
- `kubectl get clusterpolicy verify-image-signatures` shows the policy `Ready`.

You've made "only signed images run" a property of the cluster, not a hope.

## Cleanup

> Always tear down local clusters so they stop holding memory.

```bash
kubectl delete pod signed-app unsigned-app --ignore-not-found
kubectl delete -f verify-images.enforced.yaml --ignore-not-found
kind delete cluster --name pe-sign
rm -f cosign.key cosign.pub signed-image.txt verify-images.enforced.yaml
```

(The `ttl.sh` images expire on their own within an hour.)

## Reflection

- Your policy required a signature from *your* key. If it had only said
  `required: true` with no key/identity, how could an attacker still get an image in?
- The policy set `mutateDigest: true`. What race does pinning to the digest close
  between verification and the actual image pull?
- Signing proved *who* and *what*. Which earlier module proved *whether it's
  vulnerable*, and why do you need both?

## Stretch goals (optional)

- Switch the policy to `Audit` and confirm the unsigned pod is admitted but reported —
  the safe rollout path from Module 13.3.
- Add a second rule that also requires a valid **SBOM attestation** (Module 13.5) via
  `verifyImages[].attestations`, so admission checks provenance too.
- Compare your policy to
  [Project 2's keyless Pass-2 policy](../../../09-platform-project-02/gitops-platform/config-repo/platform/pass2/kyverno-verify-images.yaml)
  and list what changes between local-key and keyless enforcement.
