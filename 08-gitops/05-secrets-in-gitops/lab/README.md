# Lab — Sync a secret from a backend with External Secrets Operator

> You'll keep a secret out of Git the right way. You'll install ESO, run a local
> HashiCorp Vault as the backend, store a database URL in it, and declare a
> `SecretStore` and `ExternalSecret` (both safe to commit) that sync it into a native
> Kubernetes Secret. Then you'll rotate the value in Vault and watch ESO propagate it
> — with nothing sensitive ever touching Git.

**Estimated time:** ~45–60 minutes
**Type:** Build
**Deliverable:** A native `web-db` Secret materialized by ESO from Vault, a
demonstrated rotation, and committable manifests that contain references but no
secret values.

## Objectives

- Install ESO and a local secret backend on a kind cluster.
- Materialize a Kubernetes Secret from a backend via an `ExternalSecret`.
- Rotate a secret by changing it in the backend only.
- Confirm that what you'd commit to Git holds no secret value.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, [kind](https://kind.sigs.k8s.io/), and Helm.
- Starter manifests in this folder: [`vault-dev.yaml`](./vault-dev.yaml),
  [`secretstore.yaml`](./secretstore.yaml), [`externalsecret.yaml`](./externalsecret.yaml),
  and the optional cloud reference [`secretstore-gcp.yaml`](./secretstore-gcp.yaml).

## Steps

1. **Create a cluster and install ESO.**

   ```bash
   kind create cluster --name pe-secrets
   helm repo add external-secrets https://charts.external-secrets.io
   helm install external-secrets external-secrets/external-secrets \
     -n external-secrets --create-namespace --wait
   ```

2. **Run a local Vault (dev mode) as the backend.**

   ```bash
   kubectl apply -f vault-dev.yaml
   kubectl -n vault rollout status deploy/vault --timeout=120s
   ```

   Dev mode auto-unseals and sets the root token to `root` — lab-only, never
   production.

3. **Store a secret in Vault.** Write a database URL under `secret/web`:

   ```bash
   kubectl -n vault exec deploy/vault -- sh -c \
     'VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root \
      vault kv put secret/web database-url="postgres://app:s3cr3t@db:5432/app"'
   kubectl -n vault exec deploy/vault -- sh -c \
     'VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault kv get secret/web'
   ```

4. **Create the app namespace and the store credential.** The Vault token is the one
   secret you bootstrap out-of-band:

   ```bash
   kubectl create namespace web
   kubectl -n web create secret generic vault-token --from-literal=token=root
   ```

5. **Apply the `SecretStore` and `ExternalSecret`.** These are the manifests you'd
   commit to Git — they contain references, not values:

   ```bash
   kubectl apply -f secretstore.yaml
   kubectl apply -f externalsecret.yaml
   kubectl -n web get secretstore,externalsecret
   ```

6. **Watch ESO materialize the Secret.** ESO reads Vault and creates a native Secret:

   ```bash
   kubectl -n web get externalsecret web-db        # STATUS reaches SecretSynced
   kubectl -n web get secret web-db                # created and owned by ESO
   kubectl -n web get secret web-db -o jsonpath='{.data.DATABASE_URL}' | base64 -d; echo
   # -> postgres://app:s3cr3t@db:5432/app  (fetched from Vault, never from Git)
   ```

7. **Rotate the secret in the backend only.** Change the value in Vault and watch ESO
   propagate it within the refresh interval — no Git change, no redeploy:

   ```bash
   kubectl -n vault exec deploy/vault -- sh -c \
     'VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root \
      vault kv put secret/web database-url="postgres://app:r0tated@db:5432/app"'
   sleep 20     # refreshInterval is 15s
   kubectl -n web get secret web-db -o jsonpath='{.data.DATABASE_URL}' | base64 -d; echo
   # -> postgres://app:r0tated@db:5432/app  (ESO updated it automatically)
   ```

8. **Confirm nothing sensitive is in your "Git" artifacts.** Grep the committable
   manifests — the password appears in none of them:

   ```bash
   grep -i "s3cr3t\|r0tated\|password" secretstore.yaml externalsecret.yaml || \
     echo "No secret values in the manifests — only references. That's the point."
   ```

   In a real platform, `secretstore.yaml` and `externalsecret.yaml` live in the config
   repo and are synced by Argo CD; only the bootstrap `vault-token` is created
   out-of-band (or replaced by workload identity).

## Expected result

A native `web-db` Secret in the `web` namespace whose value came from Vault and
updated automatically when you rotated it in Vault — while the only files you would
commit to Git contain references and connection config, never the secret itself. That
is GitOps-safe secret management.

## Cleanup

> Tear everything down so nothing lingers. Never skip this.

```bash
kubectl delete -f externalsecret.yaml -f secretstore.yaml --ignore-not-found
kubectl -n web delete secret vault-token --ignore-not-found
kubectl delete namespace web --ignore-not-found
kubectl delete -f vault-dev.yaml --ignore-not-found
helm uninstall external-secrets -n external-secrets
kind delete cluster --name pe-secrets
```

## Reflection

- You rotated the password without touching Git or redeploying. Why is that safer and
  faster than storing the secret in a manifest and re-sealing or re-committing it?
- The `vault-token` Secret was created with `kubectl`, not committed. What would you
  use instead of a static root token in production, and why?
- A teammate asks to "just base64 the password into a Secret in Git for now." Using
  this lab, explain in one sentence why that is a permanent leak.

## Stretch goals (optional)

- Mount the `web-db` Secret into a Pod (`envFrom.secretRef` or a volume) and confirm a
  real workload consumes it — then rotate in Vault and restart the Pod to pick up the
  new value.
- Convert the `SecretStore` to a `ClusterSecretStore` and sync the same secret into two
  namespaces; reason about the blast-radius trade-off.
- Read [`secretstore-gcp.yaml`](./secretstore-gcp.yaml) and describe exactly which
  lines change to point ESO at a cloud secret manager instead of local Vault — and why
  the `ExternalSecret` barely changes.
