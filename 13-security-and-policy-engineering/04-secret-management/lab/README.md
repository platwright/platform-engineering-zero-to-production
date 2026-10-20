# Lab — Sync and rotate secrets with Vault + ESO

> You'll run HashiCorp **Vault** in dev mode inside a kind cluster, install the
> **External Secrets Operator (ESO)**, and sync a Vault secret into a native Kubernetes
> `Secret` using a `SecretStore` + `ExternalSecret`. Then you'll **rotate** the value in
> Vault and watch ESO re-sync it — proving that Git never holds the value and the
> platform delivers it on demand. Everything runs locally and free.

**Estimated time:** ~50–70 minutes
**Type:** Build
**Deliverable:** A Kubernetes `Secret` (`my-app-db`) materialized from Vault by ESO,
plus a demonstrated rotation where a new Vault value propagates automatically.

## Objectives

- Stand up Vault dev mode and the External Secrets Operator on a local kind cluster.
- Store a secret in Vault's KV v2 engine and reference it — never copy it — from Git.
- Materialize a native `Secret` with an `ExternalSecret` and verify it.
- Rotate the value in Vault and observe ESO re-sync within the `refreshInterval`.
- Read (as reference only) how encryption at rest and keyless cloud identity fit in.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- [Helm](https://helm.sh/) 3.x and the `base64` utility (ships with macOS/Linux; on
  Windows use WSL or Git Bash).
- Starter files in this folder: [`vault-setup.sh`](./vault-setup.sh),
  [`secret-store.yaml`](./secret-store.yaml),
  [`external-secret.yaml`](https://github.com/platwright/platform-engineering-zero-to-production/blob/main/13-security-and-policy-engineering/04-secret-management/lab/external-secret.yaml),
  [`encryption-config.yaml`](./encryption-config.yaml).

> **Scope.** This lab uses Vault **dev mode** — in-memory, auto-unsealed, guarded by a
> known root token. It is perfect for learning and completely free, but it is **never**
> a production configuration. Treat the root token as throwaway and never commit it.

## Steps

1. **Create a local cluster.**

   ```bash
   kind create cluster --name pe-secrets
   kubectl cluster-info --context kind-pe-secrets
   ```

2. **Install Vault in dev mode via Helm.** Dev mode runs a single auto-unsealed pod with
   a known root token — in-memory, local, and free.

   ```bash
   helm repo add hashicorp https://helm.releases.hashicorp.com
   helm repo update
   helm install vault hashicorp/vault \
     --namespace vault --create-namespace \
     --set "server.dev.enabled=true" \
     --set "server.dev.devRootToken=root"
   kubectl -n vault wait --for=condition=Ready pod/vault-0 --timeout=120s
   ```

3. **Enable KV v2 and write the secret.** Dev mode already mounts a KV v2 engine at
   `secret/`, so you only write the value. Run the helper script, which also shows the
   production-grade Kubernetes auth setup:

   ```bash
   ./vault-setup.sh
   ```

   Or do the core write by hand:

   ```bash
   kubectl -n vault exec vault-0 -- sh -c \
     'export VAULT_TOKEN=root; vault kv put secret/my-app/db username=app password=devpassword'
   kubectl -n vault exec vault-0 -- sh -c \
     'export VAULT_TOKEN=root; vault kv get secret/my-app/db'
   ```

4. **Install the External Secrets Operator via Helm.**

   ```bash
   helm repo add external-secrets https://charts.external-secrets.io
   helm repo update
   helm install external-secrets external-secrets/external-secrets \
     --namespace external-secrets --create-namespace \
     --set installCRDs=true
   kubectl -n external-secrets rollout status deploy/external-secrets --timeout=120s
   ```

5. **Create the app namespace and the dev-token Secret.** ESO's `SecretStore`
   authenticates to Vault using a token stored in a K8s Secret. This is **dev-only** —
   production uses the Kubernetes auth method instead (see `vault-setup.sh`).

   ```bash
   kubectl create namespace my-app
   kubectl -n my-app create secret generic vault-token --from-literal=token=root
   ```

6. **Apply the SecretStore and ExternalSecret.** Git holds only these references, never
   the password.

   ```bash
   kubectl apply -f secret-store.yaml
   kubectl apply -f external-secret.yaml
   kubectl -n my-app get externalsecret my-app-db -w
   ```

   Wait until `STATUS` shows `SecretSynced` / `Ready=True`, then press <kbd>Ctrl</kbd>+<kbd>C</kbd>.

7. **Verify the Secret materialized.** ESO created a native `Secret` from the Vault
   value — and, to prove the lesson's point, it is just base64:

   ```bash
   kubectl -n my-app get secret my-app-db -o jsonpath='{.data.password}' | base64 -d; echo
   ```

   You should see `devpassword`. Git never contained that string.

8. **Rotate the secret in Vault.** Change the source of truth; touch nothing in
   Kubernetes.

   ```bash
   kubectl -n vault exec vault-0 -- sh -c \
     'export VAULT_TOKEN=root; vault kv put secret/my-app/db username=app password=rotated123'
   ```

9. **Watch ESO re-sync.** The `ExternalSecret` has `refreshInterval: 15s`, so within a
   few seconds the K8s Secret updates on its own:

   ```bash
   sleep 20
   kubectl -n my-app get secret my-app-db -o jsonpath='{.data.password}' | base64 -d; echo
   ```

   You should now see `rotated123`. The platform delivered the new value with no manual
   `kubectl create secret` and no Git change.

10. **(OPTIONAL — needs a cloud account; may incur cost) Encryption at rest and keyless
    identity.** The core lab above is fully local. To see the control-plane pieces:

    - Read [`encryption-config.yaml`](./encryption-config.yaml) — the API-server
      `EncryptionConfiguration` that encrypts Secrets in etcd with a cloud **KMS**
      provider (with an `aescbc` fallback). On managed clusters the provider manages
      this; it is **not** applied in this kind lab.
    - On GKE/EKS, map a Kubernetes ServiceAccount to a cloud IAM identity
      (**Workload Identity** / **IRSA**) and point an ESO `SecretStore` at the cloud
      secret manager — the pod then reads cloud secrets with **no static credential**.
      This step requires a paid cloud account and is intentionally left as reading.

## Expected result

- `kubectl -n my-app get externalsecret my-app-db` reports `SecretSynced`.
- `kubectl -n my-app get secret my-app-db` exists and was created by ESO (not by you).
- Decoding `.data.password` returns `devpassword`, then `rotated123` after the rotation —
  without any change to Git or any manual Secret edit.

You're done when you can explain, pointing at your own cluster, where the secret *value*
lives (Vault), what lives in Git (a reference), and why the materialized Secret still
needs encryption at rest and tight RBAC.

## Cleanup

> Always tear down local clusters so they stop holding memory.

```bash
helm uninstall external-secrets -n external-secrets
helm uninstall vault -n vault
kind delete cluster --name pe-secrets
```

## Reflection

- Nothing you committed to Git contained `devpassword`. Trace the exact path the value
  took from Vault to the pod — which component touched it, and where it was ever
  plaintext.
- The rotation worked without redeploying. What would have to be true of a *running
  application* for it to actually pick up `rotated123` — and what breaks if it cached the
  old value at startup?
- ESO produced a normal base64 `Secret`. Which two controls from this phase still have to
  be in place for that Secret to be safe on disk and inside the cluster?

## Stretch goals (optional)

- **Dynamic secrets.** Enable Vault's database secrets engine and have Vault *generate*
  short-lived database credentials on demand, then expose them through ESO. Observe the
  lease and auto-revocation.
- **Secrets Store CSI Driver.** Install the CSI driver with the Vault provider and mount
  the same secret as a *volume* — no `Secret` object required — and contrast it with the
  ESO approach.
- **`ClusterSecretStore`.** Convert the namespaced `SecretStore` into a
  `ClusterSecretStore` shared across namespaces, and reason about the least-privilege
  trade-off you just made.
- **Kubernetes auth.** Switch the `SecretStore` from token auth to the Kubernetes auth
  method configured in `vault-setup.sh`, so no static Vault token is stored at all.
