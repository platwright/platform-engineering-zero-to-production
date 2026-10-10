# Lab — Package and distribute a chart via OCI

> You'll run a local OCI registry, package the hardened `platform-app` chart, push it
> as an OCI artifact, pull it back, and install it onto kind **straight from the
> registry** — then (stretch) attach an SBOM with ORAS. Everything runs locally and
> free on a throwaway `registry:2` container.

**Estimated time:** ~40–55 minutes
**Type:** Build
**Deliverable:** The `platform-app` chart published to a local OCI registry and
installed from it as `oci://localhost:5000/charts/platform-app`.

## Objectives

- Stand up a local OCI registry and push a packaged chart to it.
- Pull and inspect the chart as an OCI artifact; install it from the registry.
- (Stretch) Store an SBOM alongside the chart with ORAS.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- [Helm](https://helm.sh/docs/intro/install/) 3.8+ (`helm version`).
- The chart from [Module 07.2](../../02-helm-chart-development/lab/platform-app/). If
  you skipped it, run `helm create platform-app` for a stand-in chart.
- Starter file in this folder: [`values-prod.yaml`](./values-prod.yaml).

> **Port note:** these steps use host port `5000`. If it's taken (for example macOS
> AirPlay Receiver uses 5000), substitute `5001` in the `docker run` mapping and every
> `oci://localhost:5000` URL below.

## Steps

1. **Run a local OCI registry.** One container is your entire private registry:

   ```bash
   docker run -d -p 5000:5000 --name pe-registry registry:2
   curl -s http://localhost:5000/v2/_catalog      # {"repositories":[]} — empty, reachable
   ```

2. **Package the chart into a versioned artifact.** Point at the Module 07.2 chart:

   ```bash
   helm package ../../02-helm-chart-development/lab/platform-app
   ls platform-app-*.tgz                           # platform-app-1.0.0.tgz
   ```

3. **Push the chart to the registry.** `--plain-http` because the local registry is
   HTTP, not HTTPS. The chart `version` becomes the OCI tag:

   ```bash
   helm push platform-app-1.0.0.tgz oci://localhost:5000/charts --plain-http
   ```

   The output prints the pushed digest (`sha256:…`) — the immutable address of these
   exact bytes.

4. **Confirm it's really in the registry.** Ask the registry API directly:

   ```bash
   curl -s http://localhost:5000/v2/_catalog
   curl -s http://localhost:5000/v2/charts/platform-app/tags/list
   ```

   You'll see the `charts/platform-app` repository and the `1.0.0` tag — stored by the
   same registry machinery that holds container images.

5. **Inspect and pull the chart as an OCI artifact.**

   ```bash
   helm show chart oci://localhost:5000/charts/platform-app --version 1.0.0 --plain-http
   helm pull oci://localhost:5000/charts/platform-app --version 1.0.0 --plain-http
   ```

   `helm show` reads `Chart.yaml` out of the registry; `helm pull` downloads the
   `.tgz`. Note there was no `helm repo add` — the registry *is* the index.

6. **Create a cluster and install the chart from the registry.** The chart is pulled
   from your local registry by the Helm client; the app image comes from the internet:

   ```bash
   kind create cluster --name pe-oci
   helm install web oci://localhost:5000/charts/platform-app \
     --version 1.0.0 --plain-http \
     --namespace demo --create-namespace \
     -f values-prod.yaml --wait --timeout 120s
   ```

7. **Verify the release.** It's the same hardened workload — now delivered via OCI:

   ```bash
   kubectl get deploy,svc -n demo -l app.kubernetes.io/instance=web
   helm list -n demo
   ```

   The `CHART` column shows `platform-app-1.0.0`, and the release came straight from
   `oci://localhost:5000`.

## Expected result

You published `platform-app-1.0.0` to a local OCI registry, confirmed it through the
registry API, pulled and inspected it with no `helm repo add`, and installed the
hardened workload onto kind directly from `oci://localhost:5000/charts/platform-app`.
A chart travelled through the exact same registry machinery as a container image.

## Cleanup

> Tear everything down — cluster, release, registry, and files. Never skip this.

```bash
helm uninstall web -n demo
kind delete cluster --name pe-oci
docker rm -f pe-registry
rm -f platform-app-*.tgz
```

## Reflection

- You never ran `helm repo add`. What is an OCI registry giving you that a classic
  HTTP chart repo (`index.yaml` on a static site) does not?
- The push printed a `sha256:` digest. Why would a production install or an admission
  policy reference that digest instead of the `1.0.0` tag?
- Images, charts, SBOMs, and signatures can all live in one registry. What does that
  consolidation simplify for a platform team running air-gapped or multi-region?

## Stretch goals (optional)

- **Attach an SBOM with ORAS.** Install [ORAS](https://oras.land/docs/installation),
  then store a document next to your chart:

  ```bash
  echo '{"sbom":"demo","component":"platform-app","version":"1.0.0"}' > sbom.json
  oras push localhost:5000/sboms/platform-app:1.0.0 \
    --plain-http \
    --artifact-type application/vnd.example.sbom \
    sbom.json:application/json
  oras pull localhost:5000/sboms/platform-app:1.0.0 --plain-http -o ./pulled-sbom
  ```

  Clean up with `rm -f sbom.json && rm -rf ./pulled-sbom`.
- **Pin by digest.** Re-install using the `@sha256:…` digest from the push output
  instead of `--version 1.0.0`, and explain why that's stronger.
- **(Costs money / needs an account) Push to GHCR.** Create a GitHub personal access
  token with `write:packages`, `helm registry login ghcr.io`, then
  `helm push platform-app-1.0.0.tgz oci://ghcr.io/<your-user>/charts`. Delete the
  package afterward. The local registry did everything free; GHCR just shows the same
  flow on a hosted registry.
