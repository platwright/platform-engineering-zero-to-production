# Module 03.4 — Configuration

> The same container image should run in dev, staging, and production — only its
> **configuration** changes. Kubernetes separates config from image with
> **ConfigMaps** (non-sensitive) and **Secrets** (sensitive), injected at runtime as
> environment variables or mounted files. This module shows how to do that cleanly,
> and why a Kubernetes Secret is *not* encryption.

**Estimated effort:** ~2 hours (theory + lab)
**You'll need:** [Module 03.2](../02-workloads/) and a working `kubectl` +
[kind](https://kind.sigs.k8s.io/).

## Learning objectives

By the end of this module you will be able to:

- Explain why configuration belongs **outside** the image, and inject it with
  **ConfigMaps** and **Secrets**.
- Consume config three ways: single **env vars**, bulk **`envFrom`**, and **volume
  mounts**, and choose between them.
- Explain why Kubernetes Secrets are **base64-encoded, not encrypted**, and what
  actually protects them.
- Use **immutable** ConfigMaps/Secrets and understand the hot-reload trade-off.
- Describe **encryption at rest** (a KMS provider) for Secrets in etcd.

---

## 1. Concept

### Why config lives outside the image

A container image is an **immutable build artifact** (Phase 2). If you bake the
database URL or log level into the image, you need a *new image* for every
environment and every tweak — and you can no longer promote "the exact bytes that
passed testing" from staging to prod. The [Twelve-Factor App](https://12factor.net/config)
rule is: **store config in the environment**, so one image runs everywhere and only
the injected config differs.

Kubernetes gives you two objects for that injected config:

- **ConfigMap** — non-sensitive key/value data: log levels, feature flags, URLs,
  whole config files.
- **Secret** — the same idea for *sensitive* data: passwords, tokens, TLS keys.
  Treated specially (not shown in plain logs, mounted into `tmpfs`), but — crucially
  — **only base64-encoded by default, not encrypted**.

### Three ways to consume config

A Pod can read a ConfigMap or Secret in three ways:

- **Individual environment variable** (`valueFrom.configMapKeyRef` /
  `secretKeyRef`) — pull one key into one env var. Explicit and readable.
- **Bulk environment variables** (`envFrom`) — import *every* key in a ConfigMap or
  Secret as env vars at once. Convenient, but it's easy to leak surprise variables,
  and keys that aren't valid env var names are silently skipped.
- **Volume mount** — project the data as **files** in the container
  (e.g. `/etc/app/app.conf`). Best for whole config files, TLS certs, and anything
  that needs to **hot-reload**.

### The critical difference: env vars are frozen, files can update

This trips up almost everyone:

- Config injected as **environment variables is captured at container start** and
  **never changes** while the container runs. Update the ConfigMap and the env var
  keeps its old value until the Pod is **restarted**.
- Config injected as a **mounted volume updates automatically** — the kubelet
  periodically syncs the file (typically within about a minute), so a running
  process *can* pick up changes if it watches or re-reads the file.

Neither triggers your app to reload by itself — mounting just makes the *new bytes*
available; your process still has to re-read them (or you roll the Deployment).

### Secrets are not encrypted — understand what protects them

`kubectl get secret -o yaml` shows base64 — which is **encoding, not encryption**.
Anyone who can read the Secret object, or read etcd, can trivially decode it. What
actually protects Secrets:

- **RBAC** ([Module 03.6](../06-rbac/)) — restrict *who* can read Secret objects.
  This is the primary control.
- **Encryption at rest** — configure the API server with an **EncryptionConfiguration**
  so Secret values are encrypted before being written to etcd, ideally with an
  external **KMS provider** (cloud KMS) holding the key. Without this, a stolen etcd
  snapshot hands over every Secret.
- **Not committing Secrets to Git** — plain Secret manifests are base64, i.e. public.
  Use sealed/external secrets tooling (Phase 8) for GitOps.

### Immutability

Marking a ConfigMap or Secret `immutable: true` means it can't be updated in place —
you must create a new one and point workloads at it. This **protects against
accidental changes**, improves cluster performance (the kubelet stops watching it),
and makes config changes an explicit, versioned act. The trade-off: you lose
in-place hot reload; a change means a new object and a rollout.

### Configuration management patterns

- **One ConfigMap per service** — the common default; each service owns its config,
  blast radius is one service.
- **Shared ConfigMap** — for genuinely cross-cutting values (a cluster-wide DNS
  suffix). Use sparingly; a shared change touches everyone.
- **Name config by version** (e.g. `app-config-v3`) when using immutability so
  rollouts and rollbacks move config and image together.

---

## 2. Why it matters for platform engineering

- **"One artifact, many environments" is a platform promise.** Teams should build
  once and promote the same image through environments, varying only config. You
  provide the ConfigMap/Secret conventions that make that safe and boring.
- **Secrets are a top source of breaches.** Treating base64 as security, or
  committing Secrets to Git, is how credentials leak. Platform engineers set the
  guardrails: encryption at rest, RBAC on Secrets, and a sanctioned secrets workflow
  (external/sealed secrets).
- **Config drift causes incidents.** "Works in staging, breaks in prod" is usually a
  config difference. Standard config injection and review reduce that class of
  outage.
- **Hot reload vs restart is an availability decision.** Whether a config change
  needs a rollout (env) or lands live (volume) affects how teams ship changes — you
  set the pattern.

---

## 3. Mental model

Think of the image as a sealed appliance and config as the settings you dial in from
outside at power-on:

```text
          BUILD TIME (immutable)            RUN TIME (injected per environment)
   ┌────────────────────────────┐     ┌──────────────────────────────────────┐
   │   container image           │     │  ConfigMap  → env vars (frozen)       │
   │   (code + runtime, no       │  +  │  ConfigMap  → mounted files (updating)│
   │    environment-specific     │     │  Secret     → env / tmpfs files       │
   │    values baked in)         │     │  (base64, NOT encrypted by itself)    │
   └────────────────────────────┘     └──────────────────────────────────────┘
                         │                         │
                         └──────────► Pod ◄────────┘
                   same bytes in dev/stage/prod; only config differs
```

Rules to remember:

1. **Build once, configure per environment.** Never bake env-specific values in.
2. **Env vars freeze at start; mounted files can update.** Pick deliberately.
3. **A Secret is encoded, not encrypted.** RBAC + encryption at rest are what
   actually protect it.

---

## 4. Minimal implementation

Create config *outside* the image and inject it. First a ConfigMap, from a literal
and from a file (as you would in practice):

```bash
printf 'greeting = Hello from ConfigMap v1\n' > app.conf
kubectl create configmap app-config \
  --from-literal=LOG_LEVEL=info \
  --from-file=app.conf
```

Create a Secret (note: this is base64, not encryption):

```bash
kubectl create secret generic app-secret --from-literal=API_TOKEN=demo-not-a-real-secret
kubectl get secret app-secret -o jsonpath='{.data.API_TOKEN}' | base64 -d; echo   # trivially decoded
```

Inject both into a Pod — `LOG_LEVEL` as an env var, the file as a mounted volume:

```bash
kubectl run cfgtest --image=busybox:1.36 --restart=Never -it --rm \
  --overrides='{"spec":{"containers":[{"name":"c","image":"busybox:1.36","command":["sh","-c","echo LOG_LEVEL=$LOG_LEVEL; cat /etc/app/app.conf"],"env":[{"name":"LOG_LEVEL","valueFrom":{"configMapKeyRef":{"name":"app-config","key":"LOG_LEVEL"}}}],"volumeMounts":[{"name":"c","mountPath":"/etc/app"}]}],"volumes":[{"name":"c","configMap":{"name":"app-config"}}]}}'
```

You'll see `LOG_LEVEL=info` (from the env var) and the file contents (from the
volume) — the same image behaving differently purely because of injected config. The
lab turns this into a Deployment and demonstrates the env-vs-file reload difference.

---

## 5. Hands-on lab

You'll configure a Deployment from a ConfigMap and a Secret — using env vars,
`envFrom`, and a volume mount — then change the ConfigMap and watch the **mounted
file update live while the env var stays frozen** until a restart. Local kind cluster
only.

➡️ **[Start the lab: Inject config and watch hot reload](./lab/README.md)**

---

## 6. Production considerations

- **Turn on encryption at rest for Secrets.** Configure the API server with an
  `EncryptionConfiguration` backed by a **KMS provider** so a stolen etcd snapshot
  doesn't leak every credential. On managed clusters, enable the provider's
  application-layer Secret encryption.
- **Lock down Secret access with RBAC.** Reading Secrets should be a narrowly granted
  permission, not something every ServiceAccount has ([Module 03.6](../06-rbac/)).
- **Don't put Secrets in Git as plain manifests.** Adopt **External Secrets** (pull
  from a vault) or **Sealed Secrets** (encrypted until decrypted in-cluster) for
  GitOps (Phase 8).
- **Prefer immutable, versioned config for critical services.** It prevents
  accidental edits and makes config part of the deploy you can roll back.
- **Decide reload strategy explicitly.** For env-based config, a change requires a
  rollout — automate it (e.g. a checksum annotation that changes when the ConfigMap
  changes, forcing a rolling update).
- **Watch size limits.** ConfigMaps/Secrets are capped (~1 MiB). Large config or
  data belongs in a volume or object storage, not a ConfigMap.

---

## 7. Common mistakes

- **Treating base64 Secrets as secure.** — Base64 is encoding; anyone with read
  access decodes it instantly. *Fix:* enable encryption at rest, restrict Secret
  RBAC, and keep plaintext Secrets out of Git.
- **Expecting env-var config to hot-reload.** — You edit the ConfigMap and wonder why
  the app still logs at the old level. Env vars are frozen at container start. *Fix:*
  trigger a rollout on config change (or mount the config as a file and re-read it).
- **`envFrom` leaking or clobbering variables.** — Importing a whole ConfigMap/Secret
  pulls in every key, sometimes overwriting `PATH`-like vars or exposing more than
  intended. *Fix:* prefer explicit `configMapKeyRef`/`secretKeyRef` for sensitive or
  surprising keys.
- **Committing a Secret manifest to a public repo.** — The base64 value is
  effectively plaintext. *Fix:* never commit raw Secrets; use sealed/external
  secrets.
- **Baking environment-specific config into the image.** — Forces a rebuild per
  environment and breaks promotion of a tested artifact. *Fix:* keep the image
  config-free; inject at runtime.

---

## 8. Assessment

**Knowledge checks**

1. Why should configuration live outside the container image?
2. What's the practical difference between injecting config as an env var versus a
   mounted volume, especially for updates?
3. Is a Kubernetes Secret encrypted? What actually protects it?
4. When would you mark a ConfigMap `immutable: true`, and what do you give up?
5. What does `envFrom` do, and what's one risk of using it?

**Concept exercise**

> Explain how the *same* build artifact can run in dev and production with different
> database URLs and log levels — **without using the words "ConfigMap," "Secret," or
> "environment variable."** Describe the build-once, inject-later idea.

**Trade-off / debugging exercise**

> A developer updated a ConfigMap to set `LOG_LEVEL=debug` and is frustrated the app
> still logs at `info` ten minutes later. The value is consumed as an env var. Explain
> what's happening and give two ways to make the change take effect.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** The image is an immutable artifact; baking in env-specific values forces a
  rebuild per environment and prevents promoting the exact tested bytes. Inject
  config at runtime so one image runs everywhere.
- **Q2:** Env vars are captured at container start and never change until restart;
  mounted ConfigMap/Secret volumes are synced by the kubelet and update in place
  (though the app must re-read the file).
- **Q3:** No — Secret values are base64-encoded. RBAC (who can read Secrets) plus
  encryption at rest (ideally KMS-backed) are what protect them.
- **Q4:** When config shouldn't change in place — to prevent accidental edits and
  improve performance. You give up in-place hot reload; changes require a new object
  and a rollout.
- **Q5:** `envFrom` imports every key of a ConfigMap/Secret as env vars at once; the
  risk is leaking or clobbering variables you didn't intend (and silently skipping
  keys that aren't valid env var names).
- **Debugging exercise:** Env vars are frozen at container start, so editing the
  ConfigMap doesn't affect the running Pod. Fixes: roll the Deployment
  (`kubectl rollout restart`) so new Pods pick up the value, or consume the config as
  a mounted file the app re-reads. A common pattern is a checksum/hash annotation on
  the Pod template that changes with the ConfigMap, forcing an automatic rollout.

</details>

---

## 9. Further reading

- Kubernetes — [ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- Kubernetes — [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- Kubernetes — [Encrypting Secret data at rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)
- Kubernetes — [Using a KMS provider for data encryption](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/)
- The Twelve-Factor App — [III. Config](https://12factor.net/config)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 03.3 — Services and Networking](../03-services-and-networking/)
· _Next:_ [Module 03.5 — Storage →](../05-storage/)
