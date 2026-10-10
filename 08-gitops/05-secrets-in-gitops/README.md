# Module 08.5 — Secrets in GitOps

> GitOps says "put all desired state in Git" — but you must **never** put secrets in
> Git in plaintext, because Git history is permanent and world-readable to anyone
> who clones it. This module resolves that tension: keep the *reference* in Git and
> the *value* in a secret manager, and let a controller materialize the real Secret
> in-cluster. We compare Sealed Secrets, External Secrets Operator, Vault, and SOPS,
> and implement the recommended one.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 08.2 — Argo CD Fundamentals](../02-argocd-fundamentals/), Helm from [Phase 6](../../07-kubernetes-package-management/), and a kind cluster.

## Learning objectives

By the end of this module you will be able to:

- Explain why **plaintext secrets in Git are unacceptable**, and why base64 is not
  encryption.
- Compare the four mainstream patterns — **Sealed Secrets, ESO, Vault, SOPS** — and
  their trade-offs.
- Justify **External Secrets Operator (ESO)** as the default for most platforms.
- Implement an **`ExternalSecret`** that syncs a secret from a backend into a native
  Kubernetes Secret.
- Describe **secret rotation** under GitOps and where the audit trail lives.

---

## 1. Concept

### The core problem

GitOps wants everything in Git. Secrets are state. So the naive move is to commit a
Kubernetes `Secret` — but a `Secret`'s `data` is only **base64-encoded, not
encrypted**. Anyone who can read the repo can decode it in one command:

```bash
echo 'c3VwZXItc2VjcmV0LXBhc3N3b3Jk' | base64 -d      # -> super-secret-password
```

Worse, **Git history is forever**. Even if you delete the secret in a later commit,
it lives in the history, in every clone, fork, and backup. A credential committed
once must be considered compromised and rotated. So the rule is absolute: **no
plaintext secrets in Git — ever.** The whole field below exists to keep the GitOps
promise ("state in Git") without breaking that rule.

The resolution is a separation: **the reference lives in Git; the value lives in a
secret manager; a controller joins them in the cluster.** Git stays the source of
truth for *what secret a workload needs*, never for *the secret itself*.

### Four ways to do it

- **Sealed Secrets (Bitnami).** You encrypt a Secret *client-side* with `kubeseal`
  using an in-cluster controller's public key, producing a `SealedSecret` (ciphertext)
  that is safe to commit. The controller decrypts it in-cluster into a real Secret.
  - *Pros:* simple, no external system; Git holds only ciphertext.
  - *Cons:* the controller's private key is now your crown jewel (back it up, or a
    cluster loss means you can't decrypt anything); keys are per-cluster, so the same
    `SealedSecret` isn't portable; rotation and re-sealing are manual chores.
- **External Secrets Operator (ESO).** Secrets live in a dedicated **secret manager**
  (HashiCorp Vault, AWS/GCP/Azure secret managers, and many more). An `ExternalSecret`
  in Git *references* them; ESO fetches the values and **syncs** them into native
  Kubernetes Secrets, refreshing on an interval.
  - *Pros:* one source of truth for secrets with real access control, auditing, and
    rotation; Git holds only references; integrates with tools your org already uses.
  - *Cons:* you must run a secret manager and the operator.
- **Vault Agent / Secrets Store CSI driver.** Instead of creating Kubernetes Secrets,
  secrets are **injected or mounted into the Pod at runtime** straight from Vault.
  - *Pros:* secrets need never become Kubernetes `Secret` objects; supports dynamic,
    short-lived, leased credentials.
  - *Cons:* couples workloads to Vault and adds sidecar/CSI complexity; a bigger lift
    than ESO for the common case.
- **SOPS (Secrets OPerationS).** Encrypt the *values* inside a YAML/JSON file with a
  KMS key (cloud KMS, `age`, or PGP); commit the encrypted file to Git; decrypt at
  apply time.
  - *Pros:* file-level encryption that works for any config; Git-native, and Flux
    supports it directly.
  - *Cons:* key management is on you; Argo CD needs a plugin (e.g. KSOPS) to decrypt
    during render; encrypts fields in files rather than centralizing secrets.

### Why ESO is the default recommendation

For most platforms, **ESO wins** because it keeps secrets in a purpose-built manager
— the system your security team already audits, rotates, and access-controls — while
Git holds nothing sensitive at all, only a pointer. You get rotation (change the
value in the manager, ESO propagates it), a real audit trail (the manager logs
access), and least privilege (scope ESO's access per namespace/store). Sealed Secrets
is a fine lightweight start when you have no secret manager; SOPS is excellent when
you prefer file-based encryption (and especially with Flux); Vault
Agent/CSI is the choice when you need runtime injection or dynamic credentials. But
the sensible default for a GitOps platform is **ESO backed by a secret manager.**

### What goes in Git with ESO

An `ExternalSecret` is **safe to commit** — it contains no secret, only a reference:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: web-db
  namespace: web
spec:
  refreshInterval: 1h               # re-read the backend this often (rotation window)
  secretStoreRef:
    name: vault-backend             # which SecretStore (backend) to use
    kind: SecretStore
  target:
    name: web-db                    # the native K8s Secret ESO will create/own
    creationPolicy: Owner
  data:
    - secretKey: DATABASE_URL       # key in the resulting K8s Secret
      remoteRef:
        key: web                    # path/name in the backend
        property: database-url      # field within that entry
```

A **`SecretStore`** (also committable) describes *how to reach the backend* and *how
to authenticate* — the credential for the store itself is the one secret you bootstrap
out-of-band (or via workload identity in the cloud). Everything else is GitOps as
usual.

---

## 2. Why it matters for platform engineering

Secrets are where GitOps most often goes wrong, and getting them right is a core
platform responsibility:

- **One leaked commit is a permanent breach.** A platform that makes "commit a Secret"
  easy will eventually leak one irreversibly. Providing a safe, paved path (ESO +
  store) is how you prevent it by design.
- **Rotation becomes a platform feature.** With ESO, rotating a credential is "update
  it in the manager"; every consuming cluster picks it up automatically. Without it,
  rotation means hunting through repos and re-sealing files.
- **Least privilege and audit.** A secret manager gives per-secret access policies and
  an access log. The platform wires ESO to it with scoped, per-tenant permissions so
  Team A can't read Team B's secrets.
- **It closes the GitOps security story.** Modules 08.1–08.4 removed cluster
  credentials from CI; this module ensures the one thing you *don't* put in Git stays
  out of it. Project 2 requires exactly this: secrets via ESO, not plaintext files.

---

## 3. Mental model

Extend the reconcile loop to secrets with one rule: **reference in Git, value in a
vault, join in the cluster.** Git never holds the value; a controller reconciles the
native Secret from the backend.

```text
   Git repo (desired state)                     Secret manager (the VALUE)
   ┌───────────────────────┐                    ┌───────────────────────┐
   │ ExternalSecret         │   references       │ web/database-url =     │
   │  (a pointer, no value) │ ─────────────────► │   "postgres://…"       │
   └───────────┬───────────┘                    └───────────┬───────────┘
               │ Argo CD syncs the pointer                   │ ESO fetches the value
               ▼                                             ▼
          ┌──────────────────────────────────────────────────────┐
          │  cluster: ESO materializes a native Secret `web-db`    │
          │  (refreshed every interval; rotates when the backend   │
          │   value changes)                                       │
          └──────────────────────────────────────────────────────┘
```

Three rules to remember:

1. **Base64 is not encryption.** A committed `Secret` is a plaintext leak.
2. **Reference in Git, value in a manager.** Git holds a pointer; the backend holds
   the secret.
3. **Rotation = change the value in the manager.** The controller propagates it; no
   Git change needed.

---

## 4. Minimal implementation

The smallest real setup: run ESO, point a `SecretStore` at a backend, and declare one
`ExternalSecret`. ESO then creates a native Secret you can mount like any other.

```bash
# Install ESO (free, in-cluster). It serves the external-secrets.io/v1 CRDs.
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace --wait
```

```bash
# With a SecretStore and ExternalSecret applied, ESO produces a normal Secret:
kubectl -n web get externalsecret web-db        # STATUS: SecretSynced
kubectl -n web get secret web-db -o jsonpath='{.data.DATABASE_URL}' | base64 -d; echo
# -> the value, fetched from the backend — never stored in Git
```

The `ExternalSecret` and `SecretStore` are committed to Git and synced by Argo CD like
any other manifest; the sensitive value only ever exists in the backend and in the
in-cluster Secret ESO creates. The lab stands up a local Vault as the backend and
demonstrates rotation end to end.

---

## 5. Hands-on lab

You'll install ESO, run a local HashiCorp Vault (dev mode) as the secret backend,
store a database URL in it, and declare a `SecretStore` and `ExternalSecret` that sync
it into a native Kubernetes Secret. Then you'll rotate the value in Vault and watch
ESO propagate it — with nothing sensitive ever touching Git.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Lock down the store credential.** The one bootstrap secret (how ESO authenticates
  to the backend) should use workload identity (IRSA/Workload Identity) or a tightly
  scoped token, not a shared root token. In the lab we use a root token for
  simplicity — never do that in production.
- **Scope access per tenant.** Use namespaced `SecretStore`s (or carefully scoped
  `ClusterSecretStore`s) and backend policies so each team reads only its own secrets.
- **Rotation strategy.** Decide refresh intervals against your rotation SLA; shorter
  intervals propagate rotations faster but add backend load. Rotating in the manager
  should require no Git change.
- **Audit and alerting.** Rely on the backend's access log for "who read what," and
  alert on `ExternalSecret` sync failures — a stale or missing Secret is an outage
  waiting to happen.
- **Blast radius and backups.** For Sealed Secrets, back up the controller's private
  key or a cluster loss is unrecoverable. For SOPS, protect and rotate the KMS keys.
  For ESO/Vault, protect the backend and its unseal/root material.
- **Don't log or echo secrets.** Materialized Secrets are still Kubernetes Secrets —
  apply RBAC, enable encryption at rest for etcd, and avoid dumping them in CI logs.

---

## 7. Common mistakes

- **Committing a base64 `Secret` and thinking it's safe.** Base64 is encoding, not
  encryption; it's a plaintext leak with extra steps. *Fix:* never commit secret
  values — use ESO/SOPS/Sealed Secrets.
- **"We'll remove it from Git later."** History is permanent; the secret is already
  compromised across every clone. *Fix:* treat any committed secret as leaked and
  rotate it immediately.
- **Using a root/admin token for the store in production.** Convenient and
  catastrophic if leaked. *Fix:* workload identity or a least-privilege token scoped
  to the needed paths.
- **No rotation plan.** Secrets set once and never changed. *Fix:* rotate in the
  manager on a schedule; let ESO propagate; alert on failures.
- **Not backing up Sealed Secrets keys / SOPS keys.** A lost key makes every encrypted
  secret unrecoverable. *Fix:* back up and rotate key material deliberately.
- **One giant Secret for everything.** A single blob maximizes blast radius and
  over-shares. *Fix:* scope secrets per app/namespace with least-privilege access.

---

## 8. Assessment

**Knowledge checks**

1. Why is committing a base64-encoded Kubernetes `Secret` to Git unsafe?
2. Name the four approaches and give ESO's main advantage over Sealed Secrets.
3. With ESO, what exactly is stored in Git, and what is *not*?
4. How does secret rotation work under ESO, and where is it audited?
5. When might you choose Vault Agent/CSI or SOPS instead of ESO?

**Concept exercise**

> Explain how a GitOps system can "keep all state in Git" **without ever putting a
> secret value in Git** — and do it without naming ESO, Vault, or SOPS. Describe the
> reference-vs-value split so it would apply to any implementation.

**Trade-off / debugging exercise**

> A teammate commits a `Secret` with a real database password (base64) "just to
> unblock the deploy," planning to remove it tomorrow. State exactly why "remove it
> tomorrow" doesn't fix it and what must happen now. Then design the replacement: which
> approach you'd adopt for a multi-team platform, what lives in Git, and how a
> credential rotation would flow with zero Git changes.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Base64 is reversible encoding, not encryption — anyone who can read the repo
  decodes it instantly — and Git history keeps it forever, in every clone.
- **Q2:** Sealed Secrets, ESO, Vault Agent/CSI, SOPS. ESO keeps secrets in a central,
  auditable, rotatable manager with per-secret access control, and puts only
  references in Git.
- **Q3:** Git holds the `ExternalSecret` and `SecretStore` (references and connection
  config); it does **not** hold the secret value, which stays in the backend and in
  the in-cluster Secret ESO materializes.
- **Q4:** You change the value in the secret manager; ESO re-reads it on its refresh
  interval and updates the Kubernetes Secret — no Git change. The manager's access log
  is the audit trail.
- **Q5:** Vault Agent/CSI for runtime injection or dynamic/short-lived credentials;
  SOPS for file-based encryption workflows (especially with Flux) or when you don't
  want to run a secret manager.
- **Debugging:** "remove it tomorrow" fails because the password is already in history
  and every clone — it's compromised now and must be **rotated immediately** (and the
  commit history scrubbed). Replacement: ESO backed by a secret manager; Git holds the
  `ExternalSecret`/`SecretStore`; rotation is a value change in the manager that ESO
  propagates with no Git commit.

</details>

---

## 9. Further reading

- External Secrets Operator — [Documentation](https://external-secrets.io/latest/)
  and [the `ExternalSecret` API](https://external-secrets.io/latest/api/externalsecret/)
- Sealed Secrets — [Bitnami Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- SOPS — [Mozilla/`getsops` SOPS](https://github.com/getsops/sops)
- HashiCorp Vault — [Kubernetes integrations](https://developer.hashicorp.com/vault/docs/platform/k8s)
  and the [Secrets Store CSI driver](https://secrets-store-csi-driver.sigs.k8s.io/)
- Argo CD — [Secret management options](https://argo-cd.readthedocs.io/en/stable/operator-manual/secret-management/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [08.4 — Multi-Environment GitOps](../04-multi-environment-gitops/)
· _Next:_ [08.6 — GitOps Maturity Model →](../06-gitops-maturity-model/)
