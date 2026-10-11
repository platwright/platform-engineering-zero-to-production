# Lab — Measure workload cost with OpenCost

> You'll install **OpenCost** on a local kind cluster, deploy tenant workloads with
> deliberately varied resource requests, then query the **allocation API** to rank
> spend by namespace, find the **top-5 most expensive** workloads, and expose an
> **idle** team. Finally you'll chart cost in **Grafana**. Everything runs **free** —
> OpenCost uses its built-in default price list to produce *estimated* costs on kind.

**Estimated time:** ~60–80 minutes
**Type:** Build
**Deliverable:** A per-namespace cost breakdown, a top-5 costly-workload list, an
identified idle namespace, and a Grafana panel showing live cost metrics.

## Objectives

- Install OpenCost and its Prometheus backing on kind via Helm.
- Query the OpenCost allocation API by namespace and by controller.
- Distinguish expensive (high request) from wasteful (low efficiency) workloads.
- Surface OpenCost metrics in Grafana.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- [Helm](https://helm.sh/docs/intro/install/), plus [`jq`](https://jqlang.github.io/jq/)
  and `curl` for querying the API.
- Starter files here: [`prometheus-values.yaml`](./prometheus-values.yaml),
  [`opencost-values.yaml`](./opencost-values.yaml),
  [`sample-workloads.yaml`](./sample-workloads.yaml), and
  [`grafana-values.yaml`](./grafana-values.yaml).

## Steps

1. **Create a cluster.**

   ```bash
   kind create cluster --name pe-finops
   ```

2. **Install Prometheus with the OpenCost scrape job.** The starter values disable the
   heavy extras and add a scrape config so Prometheus collects OpenCost's metrics:

   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update
   helm install prometheus prometheus-community/prometheus \
     -n prometheus-system --create-namespace \
     -f prometheus-values.yaml
   kubectl -n prometheus-system rollout status deploy/prometheus-server
   ```

3. **Install OpenCost, pointed at that Prometheus.** The values tell OpenCost where the
   in-cluster Prometheus lives:

   ```bash
   helm repo add opencost https://opencost.github.io/opencost-helm-chart
   helm repo update
   helm install opencost opencost/opencost \
     -n opencost --create-namespace \
     -f opencost-values.yaml
   kubectl -n opencost rollout status deploy/opencost
   ```

4. **Deploy the tenant workloads.** Three namespaces with very different request
   profiles — a realistic web team, an over-provisioned idle batch team, and a small
   cache team:

   ```bash
   kubectl apply -f sample-workloads.yaml
   kubectl get deploy -A -l cost-lab=finops
   ```

5. **Wait for data, then port-forward the OpenCost API.** OpenCost needs a few scrape
   intervals of history before the numbers stabilize — give it ~10 minutes:

   ```bash
   sleep 600                                     # let Prometheus accumulate samples
   kubectl -n opencost port-forward svc/opencost 9003:9003 >/dev/null 2>&1 &
   ```

6. **Query cost by namespace.** This is the core allocation call — note how the request
   profiles from step 4 turn into a cost ranking:

   ```bash
   curl -sG http://localhost:9003/allocation/compute \
     -d window=1h -d aggregate=namespace -d accumulate=true \
   | jq -r '.data[0] | to_entries
            | sort_by(-.value.totalCost)
            | .[] | "\(.key)\t$\((.value.totalCost*10000|round)/10000)"'
   ```

   `team-batch` should sit at or near the top even though it serves no traffic — it
   *requested* the most. That is the attribution model doing its job.

7. **Find the top-5 most expensive workloads.** Aggregate by controller instead of
   namespace:

   ```bash
   curl -sG http://localhost:9003/allocation/compute \
     -d window=1h -d aggregate=controller -d accumulate=true \
   | jq -r '.data[0] | to_entries
            | sort_by(-.value.totalCost)
            | .[:5][] | "\(.key)\t$\((.value.totalCost*10000|round)/10000)"'
   ```

8. **Expose the idle team — cost without usage.** Cost ranks by *request*; efficiency
   ranks by *usage ÷ request*. Compare them to separate "expensive" from "wasteful":

   ```bash
   curl -sG http://localhost:9003/allocation/compute \
     -d window=1h -d aggregate=namespace -d accumulate=true \
   | jq -r '.data[0] | to_entries[]
            | "\(.key)\treqCPU=\(.value.cpuCoreRequestAverage)\tuseCPU=\(.value.cpuCoreUsageAverage)"'
   ```

   `team-batch` requests ~2 cores and uses almost none — low efficiency, high idle
   cost. That is the single clearest "right-size me" signal in the cluster, and the
   workload you'll fix in Module 18.4.

9. **(Optional) open the OpenCost UI.** A friendlier view of the same data:

   ```bash
   kubectl -n opencost port-forward svc/opencost 9090:9090 >/dev/null 2>&1 &
   # then browse to http://localhost:9090
   ```

10. **Chart cost in Grafana.** Install Grafana with the Prometheus datasource
    pre-provisioned, then confirm OpenCost metrics flow:

    ```bash
    helm install grafana grafana/grafana \
      -n grafana --create-namespace \
      -f grafana-values.yaml
    kubectl -n grafana rollout status deploy/grafana
    kubectl get secret -n grafana grafana \
      -o jsonpath='{.data.admin-password}' | base64 -d ; echo
    kubectl -n grafana port-forward svc/grafana 3000:80 >/dev/null 2>&1 &
    ```

    Log in at `http://localhost:3000` (user `admin`, password from the command above).
    In **Explore**, run the PromQL below to see the live node cost rate OpenCost
    exports — projected to a month:

    ```promql
    sum(node_total_hourly_cost) * 730
    ```

    For a full dashboard, use **Dashboards → Import** and import the community
    [OpenCost dashboard](https://grafana.com/grafana/dashboards/) (search "OpenCost"),
    selecting your Prometheus datasource.

## Expected result

- `GET /allocation/compute?aggregate=namespace` returns a cost per namespace, with
  **`team-batch` ranked most expensive** despite doing nothing — because it requested
  the most.
- The top-5 controller list is dominated by the batch workers.
- The efficiency query shows `team-batch` requesting ~2 CPU and using ~0 — a clear
  **idle / over-provisioned** signal, distinct from a genuinely busy namespace.
- Grafana plots `sum(node_total_hourly_cost) * 730`, proving cost is now a live metric
  next to your other dashboards.

You have turned "the cluster costs money" into "*this workload* costs this much, and
*that one* is wasteful" — the data every later module acts on.

## Cleanup

> Always tear down local clusters so they stop holding memory, and stop the
> port-forwards.

```bash
# stop background port-forwards started above
jobs -p | xargs -r kill
kubectl delete -f sample-workloads.yaml --ignore-not-found
helm uninstall grafana   -n grafana
helm uninstall opencost  -n opencost
helm uninstall prometheus -n prometheus-system
kind delete cluster --name pe-finops
```

## Reflection

- `team-batch` was both the **most expensive** and the **least efficient** namespace.
  Which of those two facts would you put in front of the team, and why does showing
  only the dollar figure risk the wrong conversation?
- OpenCost allocated cost by **request**, not usage. How would the namespace ranking
  change if you allocated purely by usage, and which is fairer in a shared cluster?
- The dollar numbers on kind are OpenCost's defaults. What exactly would you change to
  make them match a real GCP or AWS invoice?

## Stretch goals (optional)

- Add `-d aggregate=namespace -d window=today` and compare how the ranking shifts as
  more history accumulates.
- Query the `__idle__` allocation directly and work out what fraction of total cluster
  cost is unallocated idle — your cluster-wide efficiency number.
- Write a tiny script that fails (exit non-zero) if any namespace's CPU efficiency
  (`cpuCoreUsageAverage / cpuCoreRequestAverage`) drops below 0.2 — the seed of an
  automated right-sizing alert.
