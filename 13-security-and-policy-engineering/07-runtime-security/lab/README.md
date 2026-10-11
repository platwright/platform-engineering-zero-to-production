# Lab — Detect a shell in a pod with Falco

> You'll install **Falco** as a DaemonSet on a local kind cluster, load a custom rule,
> and exec a shell into a pod to watch the alert fire in real time. Then you'll enforce
> the **restricted** Pod Security Standard on a namespace and watch Pod Security
> Admission reject a privileged pod — detection and prevention, side by side.

**Estimated time:** ~45–60 minutes
**Type:** Build / detect
**Deliverable:** A Falco DaemonSet running on kind with a custom rule that fires when you
exec a shell into a pod (the alert captured from the logs), plus a PSS-enforced namespace
that rejects a non-hardened pod.

## Objectives

- Install Falco via Helm with the modern eBPF driver and a custom rule.
- Trigger the rule by exec'ing a shell into a running pod and capture the alert.
- Enforce Pod Security Standards `restricted` on a namespace and watch admission reject a
  non-compliant pod.
- Contrast runtime detection (Falco) with admission-time prevention (PSS) first-hand.

## Prerequisites

- Everything from [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- [Helm](https://helm.sh/docs/intro/install/) 3.x.
- A Linux kernel ≥ 5.8 with BTF for the modern eBPF driver (Docker Desktop and recent kind
  node images qualify). A fallback is noted in Step 2.
- Starter files in this directory: [`falco-values.yaml`](./falco-values.yaml),
  [`custom-falco-rule.yaml`](./custom-falco-rule.yaml),
  [`pss-namespace.yaml`](./pss-namespace.yaml), [`shell-test-pod.yaml`](./shell-test-pod.yaml).

> Run the commands from this `lab/` directory so the relative paths to the starter files
> resolve.

## Steps

1. **Create a cluster.**

   ```bash
   kind create cluster --name pe-runtime
   kubectl cluster-info --context kind-pe-runtime
   ```

2. **Install Falco with the modern eBPF driver and your custom rule.**

   ```bash
   helm repo add falcosecurity https://falcosecurity.github.io/charts
   helm repo update
   helm install falco falcosecurity/falco \
     --namespace falco --create-namespace \
     -f falco-values.yaml \
     --set-file customRules."custom-falco-rule\.yaml"=./custom-falco-rule.yaml
   ```

   The `-f falco-values.yaml` sets the driver (`modern_ebpf`) and turns on stdout output;
   `--set-file` loads your rule file into the chart's `customRules` map (equivalent to
   pasting it inline there). Wait for the DaemonSet to come up:

   ```bash
   kubectl rollout status ds/falco -n falco --timeout=180s
   kubectl get pods -n falco
   ```

   If the driver fails to load on an older kernel, reinstall with the legacy probe:

   ```bash
   helm upgrade falco falcosecurity/falco -n falco \
     -f falco-values.yaml --set driver.kind=ebpf \
     --set-file customRules."custom-falco-rule\.yaml"=./custom-falco-rule.yaml
   ```

3. **Confirm Falco started and parsed your rule.**

   ```bash
   kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=50 | grep -iE "rules loaded|Shell Spawned|Falco initialized|starting"
   ```

   You should see Falco start and load the rules file without errors.

4. **Deploy the test pod** (in the `default` namespace, which has no PSS enforcement):

   ```bash
   kubectl apply -f shell-test-pod.yaml
   kubectl wait --for=condition=Ready pod/shell-demo --timeout=60s
   ```

5. **Stream Falco alerts** in one terminal and leave it running:

   ```bash
   kubectl logs -f -n falco -l app.kubernetes.io/name=falco | grep --line-buffered -i shell
   ```

6. **Trigger the rule** in a second terminal — exec a shell into the pod and run a command:

   ```bash
   kubectl exec -it shell-demo -- /bin/sh -c "id; cat /etc/os-release"
   ```

   Within a second, the streaming terminal prints a Falco alert naming the namespace, pod,
   command, and user. That is layer-7 detection catching behaviour an admission controller
   never sees.

7. **Now add prevention: apply the restricted PSS namespace.**

   ```bash
   kubectl apply -f pss-namespace.yaml
   ```

8. **Watch admission reject a non-hardened pod.** Try to run a default (root, no seccomp,
   not hardened) pod in the restricted namespace:

   ```bash
   kubectl run rooty --image=busybox -n restricted-demo --restart=Never -- sleep 3600
   ```

   The API server rejects it with a `violates PodSecurity "restricted:latest"` error and the
   pod never schedules. The same bad posture Falco would have to *detect* at runtime is simply
   *prevented* at admission.

## Expected result

Two observations captured:

- A Falco alert from Step 6, for example:

  ```console
  Warning Shell spawned in a container (ns=default pod=shell-demo container=app
  shell=sh cmd=/bin/sh -c id; cat /etc/os-release user=root image=alpine)
  ```

- A Pod Security Admission rejection from Step 8, for example:

  ```console
  Error from server (Forbidden): pods "rooty" is forbidden: violates PodSecurity
  "restricted:latest": allowPrivilegeEscalation != false, unrestricted capabilities,
  runAsNonRoot != true, seccompProfile type unset
  ```

You've now seen the same bad behaviour handled two ways: **detected** while running (Falco)
and **prevented** before running (PSS).

## Cleanup

> Always tear down local clusters so they stop holding memory and CPU. Never skip this.

```bash
kubectl delete -f shell-test-pod.yaml --ignore-not-found
kubectl delete -f pss-namespace.yaml --ignore-not-found
helm uninstall falco -n falco
kind delete cluster --name pe-runtime
```

## Reflection

- Which layer saw the shell — admission or runtime — and why could only one of them?
- Your custom rule fired on *any* shell. In a real cluster, which legitimate shells (CI,
  operators, debug containers) would make this noisy, and how would you scope it by
  namespace, service account, or image without going blind?
- PSS rejected the non-hardened pod at admission. What attacks does that *not* prevent,
  leaving the job to Falco?

## Stretch goals (optional)

- Add a rule for an **unexpected outbound connection** or a **write below `/etc`**, then
  trigger it from inside the pod.
- Install **Falcosidekick** (`--set falcosidekick.enabled=true --set falcosidekick.webui.enabled=true`)
  and route alerts to its web UI or a Slack webhook.
- Harden `shell-test-pod.yaml` with the commented `securityContext` and schedule it *into*
  `restricted-demo` to prove it now passes admission.
- Try a **gVisor `runtimeClass`** (`runsc`) on a sandbox node and compare pod startup and
  behaviour against the default runtime.
