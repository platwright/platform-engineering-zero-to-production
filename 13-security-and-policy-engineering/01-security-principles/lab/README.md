# Lab — Baseline a cluster: CIS Benchmark + OWASP Top 10

> You'll score a local cluster against the **CIS Kubernetes Benchmark** with
> kube-bench, then walk the **OWASP Kubernetes Top 10** as a structured
> self-assessment. The output is a prioritized baseline report — the document a
> platform team publishes *before* it starts enforcing anything.

**Estimated time:** ~45–60 minutes
**Type:** Discovery / assessment
**Deliverable:** A completed [`baseline-report.md`](./baseline-report.md) with your
kube-bench findings and an OWASP Top 10 risk table, ranked by blast radius.

## Objectives

- Run kube-bench against a real (local) cluster and read its output.
- Map findings to the seven defence-in-depth layers.
- Self-assess the OWASP Kubernetes Top 10 and rank risks by impact, not count.
- Produce a prioritized remediation backlog you'll work through in this phase.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- `jq` (used for a quick RBAC check). Install from your package manager.
- Starter files here: [`kube-bench-job.yaml`](./kube-bench-job.yaml),
  [`baseline-report.md`](./baseline-report.md).

> **Note on scope.** kind runs the control plane as containers, so some control-plane
> and etcd CIS checks will not apply the way they would on a self-managed cluster.
> That's fine — the goal is to learn to *run and read* a benchmark and triage its
> output, which transfers directly to a managed or self-managed production cluster.

## Steps

1. **Create a cluster.**

   ```bash
   kind create cluster --name pe-sec-baseline
   kubectl cluster-info --context kind-pe-sec-baseline
   ```

2. **Run kube-bench as a Job.** It runs the CIS checks from inside the cluster and
   writes results to its pod log:

   ```bash
   kubectl apply -f kube-bench-job.yaml
   kubectl wait --for=condition=complete --timeout=120s job/kube-bench
   kubectl logs -f job/kube-bench | tee kube-bench-output.txt
   ```

   Each line is a control with a verdict: `[PASS]`, `[FAIL]`, `[WARN]`, or `[INFO]`.
   A `[FAIL]` is a control that is testable and not met; a `[WARN]` usually needs a
   human decision or manual check.

3. **Read the summary and the remediations.** Scroll to the per-section totals and the
   `== Remediations ==` block. For each `[FAIL]`/`[WARN]`, kube-bench prints *exactly*
   what to change. Pick the five that matter most:

   ```bash
   grep -E "\[FAIL\]|\[WARN\]" kube-bench-output.txt | head -n 40
   ```

   Don't try to fix everything. Ask of each: *which layer is this, and what's the
   blast radius if it stays broken?*

4. **Do a one-minute RBAC blast-radius check.** The most common real-world finding is
   over-broad RBAC. Count who holds `cluster-admin`:

   ```bash
   kubectl get clusterrolebindings -o json \
     | jq -r '.items[]
         | select(.roleRef.name=="cluster-admin")
         | .subjects[]? | "\(.kind)/\(.namespace // "-")/\(.name)"'
   ```

   On a fresh kind cluster this is a short, known list (system components). Note it as
   your baseline — in Module 13.2 you'll audit this properly.

5. **Walk the OWASP Kubernetes Top 10.** Open [`baseline-report.md`](./baseline-report.md)
   and fill in the risk table. For each of K01–K10, record: is this cluster exposed
   today (yes/partial/no), the evidence, and a 1–3 priority where 1 = highest blast
   radius. Use the mapping from the lesson (§1) to connect each item to a later module.

6. **Rank and commit to a backlog.** Sort your table by priority. The top three items
   are what a platform team would tackle first. Write them as the "Backlog" section of
   your report — these are the problems Modules 13.2–13.8 solve.

## Expected result

A completed `baseline-report.md` containing:

- A kube-bench summary (counts of PASS/FAIL/WARN) and your five highest-priority
  findings, each tagged with its defence-in-depth layer.
- A filled-in OWASP Top 10 table with exposure, evidence, and priority.
- A ranked top-three remediation backlog.

You're done when someone who never saw your cluster could read the report and know
*what is weak, how bad it is, and what to fix first* — in blast-radius order, not
alphabetical.

## Cleanup

> Always tear down local clusters so they stop holding memory and CPU.

```bash
kubectl delete -f kube-bench-job.yaml --ignore-not-found
kind delete cluster --name pe-sec-baseline
rm -f kube-bench-output.txt
```

## Reflection

- How many of your top findings were **configuration** (CIS-style) versus **design**
  (RBAC model, no network policy, no signing)? Which took more effort to even detect?
- A green benchmark score and a cluster that gets owned in an hour can both be true.
  After this lab, why?
- Which single finding, if left unfixed, would let one compromised pod do the most
  damage? That is your blast-radius winner.

## Stretch goals (optional)

- Run a second scanner — [kubescape](https://github.com/kubescape/kubescape)
  (`kubescape scan framework nsa`) or `trivy k8s --report summary cluster` — and
  compare what each surfaces. No single tool sees everything.
- Deliberately weaken the cluster: create a ServiceAccount and bind it to
  `cluster-admin`, re-run your Step 4 check, and watch the finding appear. Then remove
  it. This is the exact signal Module 13.2 teaches you to hunt.
- Turn your top backlog item into a one-sentence problem statement you can carry into
  the module that solves it.
