# Lab — Enforce and inject cost labels

> You'll enforce a FinOps guardrail two ways. First the **no-server** path: a
> `ValidatingAdmissionPolicy` (pure CEL) that *requires* `team` and `cost-center` labels
> on Pods in managed namespaces and rejects those that lack them. Then the **webhook**
> path: a small mutating webhook that *injects* those labels from the namespace's
> annotations, so developers never set them and the policy passes automatically.

**Estimated time:** ~60–90 minutes
**Type:** Build
**Deliverable:** A cluster where non-compliant Pods are rejected by a CEL policy, and a
mutating webhook makes bare Pods compliant by injecting cost labels.

## Objectives

- Enforce a label requirement with a server-free `ValidatingAdmissionPolicy`.
- Prove `namespaceSelector` scoping (managed vs unmanaged namespaces).
- Deploy a mutating webhook (TLS, `caBundle`, registration) that injects labels.
- See mutation (inject) run *before* validation (require), so injected Pods pass.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- **Kubernetes ≥ 1.30** (the [`kind-config.yaml`](./kind-config.yaml) pins a 1.31 node).
- **Part B only:** `openssl` and a shell (Linux/macOS/WSL2) to run
  [`gen-certs.sh`](./gen-certs.sh).
- Starter files: [`00-namespaces.yaml`](./00-namespaces.yaml),
  [`10-vap-require-labels.yaml`](./10-vap-require-labels.yaml),
  [`11-test-pods.yaml`](./11-test-pods.yaml), [`webhook.py`](./webhook.py),
  [`20-webhook-server.yaml`](./20-webhook-server.yaml),
  [`21-mutatingwebhook.yaml`](./21-mutatingwebhook.yaml), and
  [`gen-certs.sh`](./gen-certs.sh).

## Steps

### Part A — enforce with a ValidatingAdmissionPolicy (no server)

1. **Create the cluster and the namespaces.**

   ```bash
   kind create cluster --name pe-admission --config kind-config.yaml
   kubectl apply -f 00-namespaces.yaml
   ```

   `team-payments` is managed (labelled `platform.example.com/managed-by`) and carries
   `team`/`cost-center` **annotations**; `team-unmanaged` is not managed.

2. **Apply the policy and its binding.**

   ```bash
   kubectl apply -f 10-vap-require-labels.yaml
   kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding
   ```

3. **Test enforcement.** The compliant Pod has the labels; the bare one doesn't:

   ```bash
   kubectl apply -f 11-test-pods.yaml
   ```

   Expect `compliant-pod` to be **created** and `noncompliant-pod` to be **rejected**
   with `pods in managed namespaces must have a platform.example.com/cost-center label`.

4. **Prove the scoping.** The same bare Pod is fine in an unmanaged namespace, because
   the binding's `namespaceSelector` doesn't match it:

   ```bash
   kubectl run bare --image=nginx:1.27 -n team-unmanaged
   kubectl get pod bare -n team-unmanaged        # Running — policy didn't apply
   ```

   You now have un-skippable enforcement with **no TLS, no pods, no server**.

### Part B — inject the labels with a mutating webhook

1. **Deploy the webhook.** The script generates a CA and server cert, creates the TLS
   secret and the code ConfigMap, deploys the server on a stock Python image, and
   registers the `MutatingWebhookConfiguration` with the matching `caBundle`:

   ```bash
   bash gen-certs.sh
   kubectl -n platform-system get pods
   kubectl get mutatingwebhookconfiguration inject-cost-labels.platform.example.com
   ```

   Read [`webhook.py`](./webhook.py) while it rolls out: it reads the namespace's
   annotations via the API and returns a JSON Patch adding the labels.

2. **Create a bare Pod in the managed namespace — and watch it become compliant.**
   Without the webhook this Pod was rejected in Part A; now the webhook injects the
   labels *before* the policy validates it:

   ```bash
   kubectl run injected --image=nginx:1.27 -n team-payments
   kubectl get pod injected -n team-payments \
     -o jsonpath='{.metadata.labels}{"\n"}'
   ```

   The Pod exists and shows `platform.example.com/team=payments` and
   `platform.example.com/cost-center=cc-1001` — values it never declared. Mutation ran
   first, so the Pod satisfied the `ValidatingAdmissionPolicy` automatically.

3. **Confirm the webhook stays scoped.** A bare Pod in `team-unmanaged` is still
   un-mutated (the webhook's `namespaceSelector` excludes it):

   ```bash
   kubectl run bare2 --image=nginx:1.27 -n team-unmanaged
   kubectl get pod bare2 -n team-unmanaged -o jsonpath='{.metadata.labels}{"\n"}'
   ```

## Expected result

- `noncompliant-pod` is rejected by the policy; `compliant-pod` is admitted.
- In `team-unmanaged`, bare Pods are admitted and un-mutated (scoping works).
- After the webhook is deployed, a bare Pod in `team-payments` is admitted **with**
  `team` and `cost-center` labels injected from the namespace annotations.
- `kubectl get mutatingwebhookconfiguration ... -o yaml` shows a populated `caBundle`.

## Cleanup

> Delete the cluster and the local cert material. Never skip this.

```bash
kind delete cluster --name pe-admission
rm -rf ./certs
```

## Reflection

- Part A needed no server. What single capability forced you to run a server in Part B,
  and what did that add in moving parts (TLS, availability, `failurePolicy`)?
- The webhook used `failurePolicy: Ignore`. Why is that the right choice for *label
  injection*, and when would you choose `Fail` instead — accepting the risk?
- Mutation ran before validation. Walk through why that ordering is what makes
  "inject then require" work, rather than fighting each other.

## Stretch goals (optional)

- Change the webhook's `failurePolicy` to `Fail`, scale the webhook Deployment to 0, and
  try to create a Pod in `team-payments`. Observe the cluster-wide impact, then set it
  back to `Ignore`. (This is the outage mode from the lesson — feel it safely.)
- Add a `ValidatingAdmissionPolicy` that rejects the `:latest` image tag, and test it.
- Replace the hand-rolled cert with [cert-manager](https://cert-manager.io/docs/) and a
  `CA Injector` annotation, so the `caBundle` is managed and rotated for you.
- Make the webhook also inject a `pod-security` default or a sidecar container, and
  verify `reinvocationPolicy: IfNeeded` keeps the mutation idempotent.
