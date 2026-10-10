# Lab — Install, upgrade, and roll back a release

> You'll add a real Helm repository, install a chart as a **release** on a local kind
> cluster, upgrade it with an environment values file, read its **revision history**,
> and roll it back — the exact loop you run against production charts. No cloud cost.

**Estimated time:** ~40–55 minutes
**Type:** Build
**Deliverable:** A `podinfo` release you've installed from a repo, upgraded across
two environment value sets, inspected via `helm history`, and rolled back to an
earlier revision.

## Objectives

- Add a chart repository and install a pinned chart version as a named release.
- Override defaults with a per-environment values file and observe the merge.
- Upgrade, read the revision history, and roll back to a prior revision.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- [Helm](https://helm.sh/docs/intro/install/) installed (`helm version` works).
- Starter values files in this folder: [`values-dev.yaml`](./values-dev.yaml) and
  [`values-prod.yaml`](./values-prod.yaml).

## Steps

1. **Create a cluster.** One node is plenty:

   ```bash
   kind create cluster --name pe-helm
   ```

2. **Add a chart repository and look at what's available.** We use
   [podinfo](https://github.com/stefanprodan/podinfo), a tiny demo app that runs
   happily on kind:

   ```bash
   helm repo add podinfo https://stefanprodan.github.io/podinfo
   helm repo update
   helm search repo podinfo --versions | head
   ```

   `helm search repo` lists the chart versions the repo offers. Pin one of these
   deliberately in the next step — never install "whatever is latest."

3. **Render before you install.** `helm template` shows the exact YAML a release
   would create, with no cluster involved — your fastest feedback loop and the basis
   of CI review:

   ```bash
   helm template web podinfo/podinfo --version 6.7.1 -f values-dev.yaml | head -n 40
   ```

   > If `--version 6.7.1` isn't listed in step 2, pick any version from that output
   > and use it consistently for the rest of the lab.

4. **Install the chart as a release (revision 1).** Apply the dev values and wait for
   health:

   ```bash
   helm install web podinfo/podinfo --version 6.7.1 \
     -f values-dev.yaml --atomic --wait
   helm list
   kubectl get deploy,pods -l app.kubernetes.io/name=podinfo
   ```

   `helm list` shows one release, `REVISION 1`. `--atomic --wait` means a failed
   install rolls itself back instead of leaving debris.

5. **See the merged values and the live object.** Confirm the dev override actually
   took effect (one replica):

   ```bash
   helm get values web
   kubectl get deploy web-podinfo -o jsonpath='{.spec.replicas}{"\n"}'
   ```

   `helm get values` shows only *your* overrides; add `--all` to see the full merged
   set including chart defaults.

6. **Upgrade to the prod value set (revision 2).** Same chart, different knobs —
   replicas go 1 → 3:

   ```bash
   helm upgrade web podinfo/podinfo --version 6.7.1 \
     -f values-prod.yaml --atomic --wait
   kubectl get deploy web-podinfo -o jsonpath='{.spec.replicas}{"\n"}'
   ```

7. **Make a one-off change with `--set` (revision 3).** `--set` has the highest
   precedence and is perfect for an ephemeral tweak:

   ```bash
   helm upgrade web podinfo/podinfo --version 6.7.1 \
     -f values-prod.yaml --set replicaCount=2 --atomic --wait
   ```

8. **Read the release history.** Every install/upgrade/rollback is a revision:

   ```bash
   helm history web
   ```

   You should see revisions 1–3 with their status, chart version, and a description.

9. **Roll back to revision 1.** Suppose revision 3 misbehaves. Rewind to the known-good
   dev state — rollback itself is recorded as a *new* revision:

   ```bash
   helm rollback web 1 --wait
   helm history web
   kubectl get deploy web-podinfo -o jsonpath='{.spec.replicas}{"\n"}'
   ```

   Replicas are back to `1` (revision 1's state), and `helm history` now shows a
   revision 4 whose description notes it rolled back to 1.

## Expected result

You added a repo, installed a pinned chart as the release `web`, watched a
per-environment values file change the live replica count, stacked up three
revisions, and rolled back to revision 1 — with `helm history` telling the whole
story. You never edited a manifest by hand; values plus the lifecycle commands did
everything.

## Cleanup

> Tear everything down so nothing lingers. Never skip this.

```bash
helm uninstall web
kind delete cluster --name pe-helm
```

## Reflection

- `helm get values web` showed only your overrides, but the Deployment had many more
  fields set. Where did those come from, and what does that tell you about the
  values hierarchy?
- Rollback was instant and needed nothing but the cluster. What is Helm storing, and
  where, that makes that possible?
- You pinned `--version` on every command. What breaks if you don't, and why does
  that matter more in CI than on your laptop?

## Stretch goals (optional)

- Run `helm upgrade web podinfo/podinfo --version 6.7.1 --set image.tag=does-not-exist
  --atomic --wait` and watch `--atomic` automatically roll the failed upgrade back.
- Port-forward the service (`kubectl port-forward deploy/web-podinfo 9898:9898`) and
  open `http://localhost:9898` to see your `ui.message` change between dev and prod
  values.
- Inspect the raw revision storage: `kubectl get secret -l owner=helm` — each
  `sh.helm.release.v1.web.v*` Secret is one stored revision.
