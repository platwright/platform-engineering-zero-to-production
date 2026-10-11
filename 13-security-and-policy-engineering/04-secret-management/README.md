# Module 13.4 — Secret Management

> A Kubernetes `Secret` feels like a vault, but its data is just **base64 — an
> encoding, not encryption**. Anyone who can read the object, or reach etcd, reads the
> value in plaintext. This module makes secret *delivery* a platform capability: an
> external store holds the truth, an operator syncs it in, and teams reference a secret
> by name without ever handling — or committing to Git — the raw value.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 02.5 · Container Security](../../02-containerization/05-container-security/)
(secrets are never baked into images), a working `kubectl` +
[kind](https://kind.sigs.k8s.io/), and [Helm](https://helm.sh/).

## Learning objectives

By the end of this module you will be able to:

- Explain why a Kubernetes `Secret` is **base64-encoded, not encrypted**, and who can
  read it.
- Configure **encryption at rest** for etcd and say why a **KMS provider** beats a
  local key.
- Use an **external store** (HashiCorp Vault) and the **External Secrets Operator** to
  sync secrets into the cluster without putting values in Git.
- Contrast **ESO**, the **Secrets Store CSI Driver**, and **Workload Identity / IRSA**,
  and pick the right one.
- Design **rotation** so the platform re-syncs secrets and workloads tolerate change.

---

## 1. Concept

### A Kubernetes Secret is base64, not a secret

The name is a trap. A Kubernetes `Secret` is a first-class API object, but its data is
only **base64-encoded** — a reversible transport encoding with no key and no secrecy.
Anyone who can `get` the object, read a backup, or reach **etcd** (where the API server
stores it) decodes the value in one command:

```console
$ kubectl get secret my-app-db -o jsonpath='{.data.password}' | base64 -d
devpassword
```

No password was cracked; base64 is not a lock. Two consequences follow. First, **RBAC
on Secrets is load-bearing** — `get`/`list` on `secrets` is effectively "read every
credential in the namespace" (Module 13.2). Second, **the value sits in etcd in
plaintext by default**, so anyone with a disk snapshot or etcd access reads it without
ever touching the API.

### Encryption at rest: protect etcd with KMS

The API server can encrypt Secret data *before* it writes to etcd, using an
`EncryptionConfiguration` passed as `--encryption-provider-config`. You choose a
provider for the `secrets` resource:

- **`aescbc` / `secretbox`** — a symmetric key stored **in the config file on the
  control-plane node**. Better than nothing, but the key lives next to the data it
  protects; whoever reads the node reads the key.
- **`kms` (v2)** — the API server calls a **cloud KMS plugin** so the real key never
  leaves the KMS. This is **envelope encryption**: KMS holds a key-encryption key
  (KEK), each write gets a fresh data-encryption key (DEK), and only the wrapped DEK is
  stored beside the data. Rotating the KEK is a KMS operation, not a cluster migration.

```text
write: Secret → API server → [encrypt with DEK] → etcd (ciphertext)
read:  etcd (ciphertext) → API server → [decrypt] → caller with RBAC sees plaintext
                                   ▲
              KMS holds the KEK; only the wrapped DEK is stored on disk
```

Crucially, encryption at rest protects **etcd on disk** — stolen backups, raw volumes,
offline etcd. It does **nothing** against someone with `get secret` RBAC, because the
API server decrypts on read. Encryption at rest and tight RBAC are **different layers**;
you want both.

### HashiCorp Vault: the external source of truth

Encryption at rest hardens etcd, but the stronger move is to **keep the source of truth
outside the cluster entirely**, in a purpose-built store. HashiCorp **Vault** is the
canonical example:

- **KV v2 engine** — versioned key/value secrets. Every write keeps history, so you can
  read, roll back, or audit previous versions.
- **Dynamic secrets** — Vault *generates* short-lived credentials on demand (a database
  user, a cloud key) with a **lease**, then **auto-revokes** them when the lease ends.
  The credential a pod holds may be valid for an hour and never reused — there is no
  long-lived password to leak.
- **Vault Agent** — a sidecar/init container that authenticates to Vault and writes
  secrets into the pod as **files or environment variables**, keeping them out of the
  manifest entirely.

Vault authenticates workloads with its **Kubernetes auth method**: a pod presents its
ServiceAccount token, Vault verifies it with the cluster, and binds it to a **policy**
that scopes exactly which paths it may read. No static Vault token is shipped to the
app.

### External Secrets Operator: GitOps-safe sync

Vault answers "where does truth live." The **External Secrets Operator (ESO)** answers
"how does it get into Kubernetes **without putting the value in Git**." ESO is a
controller that reads from an external store (Vault, AWS/GCP/Azure managers) and
**materializes a native Kubernetes `Secret`**. Two resources drive it:

- **`SecretStore` / `ClusterSecretStore`** — *where* to fetch from and *how* to
  authenticate (namespaced vs. cluster-wide).
- **`ExternalSecret`** — *which* keys to pull and *what* K8s Secret to create, on a
  `refreshInterval`.

The payoff for GitOps: **Git holds only a reference**, never a value. An
`ExternalSecret` says "create Secret `my-app-db` from Vault path `secret/my-app/db`" —
safe to commit, diff, and review. This is exactly the decision recorded in Project 1
[ADR-005](../../04-platform-project-01/container-platform-foundation/architecture/decisions/ADR-005-why-external-secrets-operator.md)
and Project 2
[ADR-014](../../09-platform-project-02/gitops-platform/architecture/decisions/ADR-014-secrets-strategy.md):
the source of truth is a hardened store, and the config repo stays plaintext-free.

### CSI Driver and Workload Identity: fewer copies, no static creds

ESO is the common default, but it is not the only shape:

- **Secrets Store CSI Driver** — mounts secrets straight from the store as a **volume**
  in the pod, so (optionally) **no Kubernetes `Secret` object exists at all**. Fewer
  copies, but the value is present only while a pod mounts it, and consuming it as an
  env var still needs a synced Secret.
- **Workload Identity (GKE) / IRSA (EKS)** — the best end-state for *cloud* secrets and
  APIs. A Kubernetes **ServiceAccount is mapped to a cloud IAM identity**, so a pod
  calls the cloud secret manager (or any cloud API) **with no static credentials at
  all** — the cloud trusts the pod's projected token directly. There is nothing to
  rotate or leak because there is no key.

Rule of thumb: use **Workload Identity / IRSA** for cloud access, **ESO** to sync a
store into Secrets for everything else, and the **CSI Driver** to avoid a Secret object.
All three keep raw values out of Git and developers' hands.

---

## 2. Why it matters for platform engineering

- **Secret delivery is a platform capability.** Teams should never run
  `kubectl create secret`, paste a password into a values file, or hold a production
  credential. The platform provides a paved path — reference a name, get a secret — so
  being secure is the default, not a discipline.
- **GitOps stays honest.** The config repo is the source of truth for *everything
  except secret values*. ESO's reference-only model keeps the declarative model intact
  without ever committing a credential — the problem every GitOps platform must solve.
- **Blast radius shrinks.** Short-lived dynamic secrets and keyless Workload Identity
  mean a leaked credential is either already expired or never existed. Static,
  long-lived secrets are the ones that show up in breach post-mortems.
- **Rotation becomes routine, not a project.** When delivery is centralized, rotating a
  password is one write to the store; ESO re-syncs and dynamic secrets rotate by
  design. Without it, rotation means hunting copies across namespaces and repos.
- **It closes an OWASP risk by construction.** "Secrets management failures" (OWASP
  K08) is a top Kubernetes risk; making the secure path the easy path removes the
  motivation to paste a secret into a ConfigMap.

---

## 3. Mental model

Hold one picture: **the platform is a delivery pipe, not a storage box.** Secrets live
in a hardened store; the platform *delivers* them to pods on demand and keeps the raw
value out of Git and out of human hands.

```text
  SOURCE OF TRUTH          PLATFORM (delivery)          WORKLOAD
  ┌───────────────┐                                    ┌───────────┐
  │ Vault / cloud │        ExternalSecret              │    Pod    │
  │ secret store  │   (a reference, lives in Git)      │  reads    │
  │ KV v2·dynamic │                                    │  env/file │
  └──────┬────────┘                                    └─────▲─────┘
         │ 1. authenticate + fetch                           │
         ▼                                                   │ 3. consume
   ┌───────────┐  2. materialize    ┌────────────────────┐  │
   │    ESO    │───────────────────▶│ K8s Secret (base64) │──┘
   │ controller│   every refresh    │ stored in etcd      │
   └───────────┘                    └─────────┬──────────┘
                                              │ encryption at rest
                                              ▼ (API server + KMS)
                                       ┌──────────────┐
                                       │ etcd on disk │  ciphertext
                                       │ (KMS/aescbc) │
                                       └──────────────┘

  Git holds only a reference · RBAC guards the Secret · KMS guards etcd on disk
```

Three independent protections, three different layers:

- **Reference-only in Git** keeps values out of version control.
- **RBAC on the Secret** ([Module 13.2](../02-kubernetes-rbac-deep-dive/)) controls who
  reads it *inside* the cluster.
- **Encryption at rest** controls who reads **etcd on disk** outside the API.

Keyless **Workload Identity / IRSA** is the same pipe with one segment removed: the
pod's identity *is* its credential, so there is no stored secret to protect at all.

---

## 4. Minimal implementation

Start with the problem. Create an ordinary Secret and "read" it the way an attacker
would:

```console
$ kubectl create secret generic my-app-db \
    --from-literal=username=app --from-literal=password=devpassword

$ kubectl get secret my-app-db -o jsonpath='{.data.password}' | base64 -d
devpassword
```

The value round-trips through `base64 -d` with no key. Commit that manifest to a GitOps
repo and the plaintext (base64) is in Git history forever. That is the whole problem:
the Secret is not secret, and committing it is worse.

The fix is to never create the Secret by hand. Keep the value in Vault and let ESO
materialize it from a **reference**:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-db
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: vault-dev
    kind: SecretStore
  target:
    name: my-app-db          # the K8s Secret ESO creates
  data:
    - secretKey: password
      remoteRef:
        key: my-app/db       # Vault: mount "secret" + key "my-app/db"
        property: password
```

This manifest is safe to commit: it names a Vault path, not a password. ESO reads
`secret/my-app/db` from Vault and creates (and keeps refreshing) the `my-app-db` Secret.
To **rotate**, you never touch Kubernetes — write a new value to Vault and ESO re-syncs
within `refreshInterval`:

```console
$ vault kv put secret/my-app/db username=app password=rotated-$(date +%s)
Success! Data written to: secret/my-app/db
```

The lab builds this end to end — Vault in dev mode, ESO via Helm, a synced Secret, and
a live rotation — all locally and free.

---

## 5. Hands-on lab

You'll run **HashiCorp Vault** in dev mode inside a kind cluster, install the **External
Secrets Operator**, sync a Vault secret into a native Kubernetes `Secret` with an
`ExternalSecret`, and then **rotate** it — watching ESO re-sync — all locally and at no
cost.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Encryption at rest is table stakes — use KMS, not a local key.** On managed
  clusters, enable the provider's KMS-backed Secret encryption (or run your own
  `EncryptionConfiguration` with a `kms` provider). An `aescbc` key in a file on the
  node is a weak second choice. (See
  [`lab/encryption-config.yaml`](./lab/encryption-config.yaml).)
- **Prefer keyless identity.** Workload Identity (GKE) / IRSA (EKS) removes static cloud
  credentials entirely; reach for it before shipping any long-lived key. The best secret
  is the one that does not exist.
- **Favor short-lived, dynamic secrets.** Vault dynamic database/cloud credentials with
  short leases turn "rotate the password" into "the credential already expired." Design
  apps to **re-read** secrets, not cache them forever.
- **Secrets still land as K8s Secrets — defend that layer.** Even with ESO, the value
  materializes in etcd. Keep **encryption at rest on** and **RBAC on `secrets` tight**
  (Module 13.2). ESO is not a substitute for those; it feeds them.
- **Scope SecretStore auth least-privilege.** A `ClusterSecretStore` is convenient but
  cluster-wide; prefer namespaced `SecretStore`s with Vault policies that grant only the
  paths a team needs. Authenticate workloads with the **Kubernetes auth method**, never
  a shared static token.
- **Mind rotation latency and failure modes.** `refreshInterval` is a trade-off: short
  means fast rotation and more load; long means staleness. Alert when ESO cannot reach
  the store — a failed sync leaves pods on the *last good* value, which can mask an
  outage.
- **Audit and limit sprawl.** Every copy is attack surface. Track where secrets land,
  who can read them, and prune Secrets no `ExternalSecret` owns.

---

## 7. Common mistakes

- **Treating base64 as encryption.** Committing a `Secret` manifest "because it's
  encoded." base64 is reversible with zero effort. *Fix:* keep values in a store; commit
  only an `ExternalSecret` reference.
- **Secrets in ConfigMaps, env literals, or values files.** Pasting a password into a
  Helm `values.yaml` or a plain env var to "move fast." It ends up in Git and image
  layers. *Fix:* route every secret through ESO / CSI / Workload Identity.
- **Assuming ESO encrypts the Secret.** ESO syncs *into* a normal K8s Secret — still
  base64 in etcd. *Fix:* pair ESO with encryption at rest and tight RBAC; they are
  different layers.
- **One `ClusterSecretStore` with god-mode auth.** A single cluster-wide store whose
  credential can read every path. *Fix:* namespaced stores, least-privilege Vault
  policies, Kubernetes auth per workload.
- **Shipping a static Vault or cloud token into the pod.** Defeats the point — you've
  just moved the long-lived secret. *Fix:* Kubernetes auth method or Workload Identity so
  the pod's identity *is* the credential.
- **Apps that read a secret once and cache forever.** Rotation re-syncs the Secret, but a
  process that read the old env var never notices. *Fix:* re-read on an interval, watch
  the mounted file, or restart on change.

---

## 8. Assessment

**Knowledge checks**

1. Why is a Kubernetes `Secret` not actually secret, and which two different controls
   protect it on disk versus inside the cluster?
2. What does an `EncryptionConfiguration` protect against, and why is a `kms` provider
   stronger than an `aescbc` key in the config file?
3. In the ESO model, what exactly lives in Git, and what never does?
4. How does **Workload Identity / IRSA** let a pod reach cloud secrets with no static
   credential?
5. Describe how a rotation propagates from the store to a running pod, and one reason the
   pod might still use the old value.

**Concept exercise**

> Explain, **without naming Vault or the External Secrets Operator**, how a platform can
> let a team deploy an app that needs a database password while guaranteeing the password
> is never written in Git, never typed by a developer, and changeable without
> redeploying. What has to be true of the store, the sync, and the app?

**Trade-off / debugging exercise**

> A team reports their app still authenticates with the **old** password an hour after
> you rotated it in the store. The `ExternalSecret` has `refreshInterval: 1h`, the synced
> `Secret` *does* show the new value, and the pod has not restarted. Walk through where
> the staleness is, what you'd check, and two different fixes — one in the platform, one
> in the app.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Not secret:** `Secret` data is base64 — reversible with `base64 -d`, no key. On disk
  it is protected by **encryption at rest** (API server + KMS over etcd); inside the
  cluster it is protected by **RBAC** on the `secrets` resource. Different layers, both
  needed.
- **EncryptionConfiguration:** protects **etcd at rest** (stolen disks, backups, raw
  etcd). A `kms` provider keeps the key-encryption key in an external KMS (envelope
  encryption), so the key never sits next to the data and rotation is a KMS operation;
  `aescbc` stores the key in a file on the control-plane node.
- **Git:** holds only the `ExternalSecret` / `SecretStore` **references** (paths, store
  names) — never the secret value. The value lives in the external store and lands as a
  K8s Secret the operator creates.
- **Workload Identity / IRSA:** a K8s ServiceAccount is federated to a cloud IAM
  identity; the cloud trusts the pod's projected token directly, so the pod calls the
  secret manager with **no stored key** to rotate or leak.
- **Rotation path:** write to the store → ESO re-syncs on `refreshInterval` → the K8s
  Secret updates. The pod may still use the old value because it read the env var/file
  **once at startup** and cached it, or it has not restarted. Fixes: shorten
  `refreshInterval` and roll/annotate the Deployment on change (platform side); make the
  app **re-read** the mounted secret or watch the file (app side).

</details>

---

## 9. Further reading

- HashiCorp — [Vault documentation](https://developer.hashicorp.com/vault/docs)
- External Secrets Operator — [Documentation](https://external-secrets.io/latest/)
- Kubernetes SIG — [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/)
- Kubernetes — [Encrypting Secret Data at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)
- Google Cloud — [GKE Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
  · AWS — [EKS IAM Roles for Service Accounts (IRSA)](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- SPIFFE — [Secure identity for workloads](https://spiffe.io/docs/latest/spiffe-about/overview/) (optional)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 13.3 — Policy as Code with Kyverno](../03-policy-as-code-with-kyverno/)
· _Next:_ [Module 13.5 — Supply Chain Security →](../05-supply-chain-security/)
