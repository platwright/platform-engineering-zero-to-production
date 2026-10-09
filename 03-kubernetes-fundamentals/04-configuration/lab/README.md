# Lab — Inject config and watch hot reload

> You'll configure one Deployment from a ConfigMap and a Secret — as env vars,
> `envFrom`, and a mounted file — then change the ConfigMap and watch the **mounted
> file update live while the env var stays frozen** until a restart. You'll also
> decode a Secret to prove base64 is not encryption. Local kind cluster only.

**Estimated time:** ~40–50 minutes
**Type:** Build
**Deliverable:** A running workload configured entirely from outside its image, plus
notes contrasting env-var config (frozen) with volume-mounted config (hot-reloads).

## Objectives

- Inject config as env vars, bulk `envFrom`, and a mounted file.
- Observe that mounted config updates live but env-var config does not.
- Demonstrate that a Secret is only base64-encoded.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- Starter manifests here: [`configmap.yaml`](./configmap.yaml),
  [`secret.yaml`](./secret.yaml), and [`deployment.yaml`](./deployment.yaml).

## Steps

1. **Create a cluster.**

   ```bash
   kind create cluster --name pe-config
   ```

2. **Create the config objects.** Apply the ConfigMap and Secret, then look at how
   the Secret is stored:

   ```bash
   kubectl apply -f configmap.yaml
   kubectl apply -f secret.yaml
   kubectl get secret app-secret -o jsonpath='{.data.API_TOKEN}'; echo
   kubectl get secret app-secret -o jsonpath='{.data.API_TOKEN}' | base64 -d; echo
   ```

   The stored value is base64; one command decodes it. That's **encoding, not
   encryption** — RBAC and encryption-at-rest are what protect Secrets.

3. **Deploy the app and read its injected config.** It reads `LOG_LEVEL` as an env
   var, the Secret via `envFrom`, and `app.conf` as a file:

   ```bash
   kubectl apply -f deployment.yaml
   kubectl rollout status deployment/config-demo

   kubectl exec deploy/config-demo -- sh -c 'echo "env LOG_LEVEL=$LOG_LEVEL"; echo "env API_TOKEN=$API_TOKEN"'
   kubectl exec deploy/config-demo -- cat /etc/app/app.conf
   ```

   You should see `LOG_LEVEL=info`, the decoded `API_TOKEN`, and the `v1` greeting
   file — the same image behaving per its injected config.

4. **Change the ConfigMap.** Update both the scalar `LOG_LEVEL` and the file
   `greeting` to a `v2` value:

   ```bash
   kubectl patch configmap app-config --type=merge -p '{"data":{"LOG_LEVEL":"debug"}}'
   kubectl patch configmap app-config --type=merge \
     -p '{"data":{"app.conf":"# application configuration\nlog_level = debug\ngreeting  = Hello from ConfigMap v2\n"}}'
   ```

5. **Watch the mounted file hot-reload (but not the env var).** The kubelet syncs
   mounted ConfigMaps periodically (up to ~60–90s). Poll the file; it will flip to
   `v2`. The env var will **not** change:

   ```bash
   # Re-read every 10s; the file greeting changes to v2 within ~1-2 minutes.
   for i in $(seq 1 12); do
     echo "--- attempt $i ---"
     kubectl exec deploy/config-demo -- sh -c 'echo "file: $(grep greeting /etc/app/app.conf)"; echo "env : LOG_LEVEL=$LOG_LEVEL"'
     sleep 10
   done
   ```

   The **file** shows `v2`, but the **env** `LOG_LEVEL` is still `info` — env vars are
   captured at container start and frozen.

6. **Make the env var update the only way it can: a rollout.** Restart the Deployment
   so new Pods capture the new value:

   ```bash
   kubectl rollout restart deployment/config-demo
   kubectl rollout status deployment/config-demo
   kubectl exec deploy/config-demo -- sh -c 'echo "env LOG_LEVEL=$LOG_LEVEL"'   # now debug
   ```

## Expected result

You configured one image three different ways, decoded a Secret to show base64 isn't
security, watched a mounted config file update live, confirmed the env var stayed
frozen until a restart, and used `rollout restart` to pick up the new env value. You
now know exactly which config mechanism reloads and which doesn't.

## Cleanup

> Tear the cluster down so it stops holding memory. Never skip this.

```bash
kubectl delete -f deployment.yaml --ignore-not-found
kubectl delete -f secret.yaml --ignore-not-found
kubectl delete -f configmap.yaml --ignore-not-found
kind delete cluster --name pe-config
```

## Reflection

- Which config mechanism (env var vs mounted file) would you choose for a value that
  must change without downtime, and why?
- You decoded the Secret with one command. List two controls that would actually
  protect it in production.
- A common production trick is a Pod-template annotation containing a hash of the
  ConfigMap. Why would that make env-var config changes "just work" on `kubectl
  apply`?

## Stretch goals (optional)

- Recreate the ConfigMap as **immutable** (`immutable: true`) and try to `kubectl
  edit` it — observe that updates are rejected, and reason about the hot-reload
  trade-off.
- Switch the Deployment from `env` to `envFrom.configMapRef` for the whole ConfigMap
  and observe that the dotted key `app.conf` is skipped as an invalid env var name.
- Create the ConfigMap imperatively instead:
  `kubectl create configmap app-config --from-literal=LOG_LEVEL=info --from-file=app.conf`.
