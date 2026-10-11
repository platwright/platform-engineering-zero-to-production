# Lab — Enforce cost labels and report per team

> You'll enforce a `require-cost-labels` policy so every workload is attributable,
> watch Kyverno **block** an unlabeled Deployment and **admit** a compliant one, then
> run a **weekly per-team cost report** that summarizes OpenCost allocation and can
> post to Slack. The report works against live OpenCost *or* a bundled sample, so this
> lab stands alone on a fresh cluster.

**Estimated time:** ~45–60 minutes
**Type:** Build
**Deliverable:** An enforced `require-cost-labels` ClusterPolicy (with a rejected-vs-
admitted pair as evidence) and a generated per-team cost report.

## Objectives

- Apply and promote a cost-label policy from Audit to Enforce.
- Prove attribution is enforced: a non-compliant workload is rejected.
- Generate a per-team cost summary and optionally push it to Slack.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- [Helm](https://helm.sh/docs/intro/install/) (to install Kyverno), plus `jq` and
  `curl`.
- Starter files here: [`require-cost-labels.yaml`](./require-cost-labels.yaml),
  [`good-deployment.yaml`](./good-deployment.yaml),
  [`bad-deployment.yaml`](./bad-deployment.yaml),
  [`weekly-cost-report.sh`](./weekly-cost-report.sh), and
  [`sample-allocation.json`](./sample-allocation.json).
- Optional: a running OpenCost from [Module 18.2](../../02-kubernetes-cost-management/lab/)
  if you want a live report instead of the sample.

## Steps

1. **Create a cluster and install Kyverno.**

   ```bash
   kind create cluster --name pe-finops-attr
   helm repo add kyverno https://kyverno.github.io/kyverno/
   helm repo update
   helm install kyverno kyverno/kyverno -n kyverno --create-namespace
   kubectl -n kyverno rollout status deploy/kyverno-admission-controller
   ```

2. **Apply the cost-label policy (ships in Audit).** Nothing is blocked yet —
   violations are only recorded:

   ```bash
   kubectl apply -f require-cost-labels.yaml
   kubectl get clusterpolicy require-cost-labels
   ```

   Confirm `ACTION: Audit` and `READY: True`.

3. **Create the unlabeled workload and see it admitted-but-reported.** In Audit the bad
   Deployment still runs — that's the point of Audit:

   ```bash
   kubectl create namespace team-payments
   kubectl apply -f bad-deployment.yaml
   kubectl -n team-payments get deploy legacy-billing   # it exists under Audit
   ```

4. **Read the policy report — the gap, without blocking anyone.**

   ```bash
   kubectl -n team-payments get policyreport -o wide
   kubectl -n team-payments describe policyreport | grep -A3 -i fail | head -n 30
   ```

   You should see a `fail` for `legacy-billing` against `require-cost-labels`. On a real
   cluster this report is how you size the backfill *before* enforcing.

5. **Promote the policy to Enforce.** Flip the single field that turns a report into a
   guardrail:

   ```bash
   kubectl patch clusterpolicy require-cost-labels --type=merge \
     -p '{"spec":{"validationFailureAction":"Enforce"}}'
   kubectl get clusterpolicy require-cost-labels      # ACTION now Enforce
   ```

6. **Prove enforcement: the unlabeled workload is now rejected.**

   ```bash
   kubectl -n team-payments delete deploy legacy-billing --ignore-not-found
   kubectl apply -f bad-deployment.yaml      # ← REJECTED at admission
   ```

   Read the error — it names the three missing cost labels. No human had to review it.

7. **Prove the paved road still works: the labeled workload is admitted.** Note the
   cost labels are on the **pod template**, which is where OpenCost reads them:

   ```bash
   kubectl apply -f good-deployment.yaml
   kubectl -n team-payments get deploy payments-api     # Running
   kubectl -n team-payments get pod -l platform.example.com/team \
     -o jsonpath='{.items[0].metadata.labels}' ; echo
   ```

8. **Generate the weekly per-team report from the sample.** This runs with no OpenCost
   required — it reads the bundled allocation response:

   ```bash
   chmod +x weekly-cost-report.sh
   ./weekly-cost-report.sh sample-allocation.json
   ```

   You'll see each namespace ranked by cost, the `__idle__` line, and a total — the
   shape of what lands in a team's channel every Monday.

9. **(Optional) run it against live OpenCost.** If you still have the Module 18.2 stack
   up and port-forwarded on `9003`:

   ```bash
   OPENCOST_URL=http://localhost:9003 WINDOW=1h ./weekly-cost-report.sh
   ```

10. **(Optional, needs a Slack workspace) post to Slack.** Create an
    [incoming webhook](https://api.slack.com/messaging/webhooks) and export it — the
    script posts automatically when the variable is set:

    ```bash
    export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/XXX/YYY/ZZZ"
    ./weekly-cost-report.sh sample-allocation.json
    ```

## Expected result

- Under **Enforce**, `bad-deployment.yaml` is **rejected** with a message naming the
  missing `platform.example.com/team`, `/environment`, and `/cost-center` labels.
- `good-deployment.yaml` is **admitted**, and its pods carry the cost labels.
- `weekly-cost-report.sh` prints a per-namespace cost ranking with a total (and posts
  to Slack if configured).

You've made attribution **structural**: unlabeled, unattributable spend can no longer
enter the cluster, and the people who own each number get it pushed to them.

## Cleanup

> Always tear down local clusters so they stop holding memory.

```bash
kubectl delete -f good-deployment.yaml --ignore-not-found
kubectl delete -f bad-deployment.yaml  --ignore-not-found
kubectl delete -f require-cost-labels.yaml --ignore-not-found
kind delete cluster --name pe-finops-attr
```

## Reflection

- You enforced labels on `Deployment` and `StatefulSet`. Which workload kinds slip
  through that match, and how would an attacker-of-convenience (a hurried engineer)
  accidentally create unattributable spend anyway?
- The report ranks `team-batch` highest and shows a large `__idle__` line. Which of
  those two numbers would you escalate first, and to whom?
- You started the policy in Audit. On a 500-workload production cluster, what would you
  do during the Audit window before daring to flip Enforce?

## Stretch goals (optional)

- Add a Kyverno **mutate** rule that defaults `platform.example.com/cost-center` from a
  namespace annotation, so teams only have to supply the labels a human must choose.
- Extend the report script to compute **week-over-week change** per team and flag any
  team whose cost rose more than 20% — the seed of anomaly alerting (Module 18.5).
- Add a `validate` rule that rejects `environment` values outside
  `{production,staging,development}` so the dimension can't fracture into synonyms.
