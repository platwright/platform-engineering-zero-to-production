# Lab — Build the platform-app chart

> You'll take a real, hardened starter chart — `platform-app`, the golden-path
> workload — lint it, read its rendered security defaults, watch its schema reject
> bad input, install it on kind, verify the live pod is non-root and read-only, run
> its `helm test`, and package it. This is the chart every team in later phases
> consumes. No cloud cost.

**Estimated time:** ~50–70 minutes
**Type:** Build
**Deliverable:** A linted, rendered, installed, self-tested, and packaged
`platform-app` chart, plus proof (from the live pod) that the hardened defaults
took effect.

## Objectives

- Read a production-grade chart: helpers, schema, hardened templates, `helm test`.
- Prove `values.schema.json` rejects bad input before it reaches the cluster.
- Install the chart, verify hardening on the running pod, and run its smoke test.
- Package the chart into a versioned artifact.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- [Helm](https://helm.sh/docs/intro/install/) installed (`helm version` works).
- Starter chart in this folder: [`platform-app/`](./platform-app/), and a sample
  consumer file [`consumer-values.yaml`](./consumer-values.yaml).

## Steps

1. **Tour the chart.** Look at what a platform-grade chart contains:

   ```bash
   find platform-app -type f | sort
   ```

   Note the parts: `Chart.yaml` (metadata), `values.yaml` (hardened defaults),
   `values.schema.json` (input validation), `templates/_helpers.tpl` (shared
   labels/names), the workload templates, and `templates/tests/` (the `helm test`).

2. **Lint it.** Static checks plus schema validation of the default values:

   ```bash
   helm lint ./platform-app
   ```

   Expect `0 chart(s) failed`. The only note is an optional `icon` recommendation.

3. **Read the hardened output — no cluster needed.** Render and confirm the security
   defaults are really there:

   ```bash
   helm template web ./platform-app \
     | grep -E 'runAsNonRoot|readOnlyRootFilesystem|allowPrivilegeEscalation|drop:|- ALL'
   ```

   Every pod the chart produces is non-root, read-only-rootfs, and drops all Linux
   capabilities — the consumer wrote none of that.

4. **Watch the schema protect consumers.** Try to set values that are the wrong type
   or simply don't exist. Both are rejected *before* any manifest is produced:

   ```bash
   helm template web ./platform-app --set replicaCount=two
   helm template web ./platform-app --set bogusKey=1
   ```

   You'll see `Invalid type. Expected: integer` and
   `Additional property bogusKey is not allowed`. That's a whole class of mistakes
   turned into an instant, local error.

5. **Create a cluster and install the chart.** Install as a consumer would, into its
   own namespace:

   ```bash
   kind create cluster --name pe-chart
   helm install web ./platform-app \
     --namespace demo --create-namespace \
     --atomic --wait --timeout 120s
   ```

   The post-install NOTES summarize what was created. `--atomic` rolls the release
   back automatically if the pods don't come up healthy.

6. **Inspect what the chart created.** One install produced a whole hardened bundle:

   ```bash
   kubectl get deploy,svc,hpa,pdb,netpol,sa -n demo \
     -l app.kubernetes.io/instance=web
   ```

   > The HPA will show `TARGETS <unknown>` because this kind cluster has no
   > metrics-server — that's expected. The HPA *object* is still created; wiring up
   > metrics is a cluster concern, not a chart concern.

7. **Prove the hardening is live, not just rendered.** Read the security context off
   the running pod:

   ```bash
   kubectl get pod -n demo -l app.kubernetes.io/instance=web \
     -o jsonpath='{.items[0].spec.containers[0].securityContext}{"\n"}'
   ```

   You should see `readOnlyRootFilesystem:true`, `allowPrivilegeEscalation:false`,
   `runAsNonRoot:true`, and `capabilities.drop:[ALL]`.

8. **Run the chart's own smoke test.** `helm test` runs the hardened test pod, which
   curls the release's `/readyz` through its Service:

   ```bash
   helm test web -n demo
   ```

   Expect `Phase: Succeeded`. This proves the release is actually *serving*, not
   merely that its objects exist.

9. **Consume the golden path as a team would.** Re-use the same chart with a few
   overrides — note you still write zero security config:

   ```bash
   helm upgrade web ./platform-app -n demo \
     -f consumer-values.yaml --atomic --wait --timeout 120s
   kubectl get deploy web-platform-app -n demo \
     -o jsonpath='{.spec.replicas}{"\n"}'
   ```

   Replicas are now `3` (the consumer chose static sizing), yet the hardened defaults
   are untouched.

10. **Package the chart into a versioned artifact.** This is the thing you'd publish
    (Module 07.5):

    ```bash
    helm package ./platform-app
    ls platform-app-*.tgz
    ```

    You now have `platform-app-1.0.0.tgz` — a single, versioned, distributable file.

## Expected result

You linted a hardened chart, saw its schema reject bad input, installed it to get a
non-root / read-only / capability-dropped workload plus a Service, HPA, PDB,
NetworkPolicy, and ServiceAccount from one command, confirmed the hardening on the
*live* pod, passed `helm test`, consumed it as an app team with a few overrides, and
packaged it into `platform-app-1.0.0.tgz`.

## Cleanup

> Tear everything down. Never skip this.

```bash
helm uninstall web -n demo
kind delete cluster --name pe-chart
rm -f platform-app-*.tgz
```

## Reflection

- A consumer set four values and got a secure, autoscaled, availability-protected
  workload. Which of those guarantees would a hand-written manifest most often get
  wrong, and why does baking them into the chart matter at fleet scale?
- The schema rejected `bogusKey` thanks to `additionalProperties: false`. What's the
  trade-off of being that strict, and when might you loosen it?
- `helm test` needs a live release; the schema check needs no cluster at all. Where
  does each belong in a CI pipeline, and why run the cluster-free check first?

## Stretch goals (optional)

- Break the hardening on purpose: `helm upgrade web ./platform-app -n demo
  --set securityContext.readOnlyRootFilesystem=false --reuse-values`, then re-read
  the live pod to confirm the change — and reflect on why the *default* is the safer
  place for that setting.
- Add a `pre-upgrade` hook Job to `templates/` (annotated `helm.sh/hook: pre-upgrade`)
  that echoes a "running migration" message, then watch it run on the next upgrade.
- Install the [`helm-unittest`](https://github.com/helm-unittest/helm-unittest)
  plugin and write a test asserting that `autoscaling.enabled=false` renders a
  `replicas` field and no `HorizontalPodAutoscaler`.
