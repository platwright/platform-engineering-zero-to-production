# Module 03.9 — Debugging and Troubleshooting

> When a workload is red, guessing is slow and stressful. A **repeatable debugging
> workflow** turns "it's broken" into a root cause in minutes. This module gives you
> that workflow — status → describe → events → logs → exec — and then drills the five
> failure modes you'll meet again and again: `CrashLoopBackOff`, `ImagePullBackOff`,
> `OOMKilled`, `Pending`, and the silently unreachable Service.

**Estimated effort:** ~2.5–3 hours (theory + lab)
**You'll need:** everything from [Module 03.1](../01-kubernetes-architecture/) through
[03.8](../08-health-and-scheduling/), and a working `kubectl` + [kind](https://kind.sigs.k8s.io/).

## Learning objectives

By the end of this module you will be able to:

- Apply a **systematic debugging workflow** instead of guessing.
- Read a Pod's **status, conditions, and events** with `kubectl describe`.
- Get the right **logs**, including a crashed container's **previous** logs.
- Use `kubectl exec`, **ephemeral debug containers**, and **port-forward** to
  investigate.
- Diagnose and fix the **five classic failure modes** by their signatures.

---

## 1. Concept

### The workflow: stop guessing, start narrowing

Almost every Kubernetes problem yields to the same funnel. Run it in order; each step
either answers the question or points to the next:

```text
1. kubectl get pods        → WHAT is the state? (Pending / ImagePullBackOff / CrashLoop / OOMKilled)
2. kubectl describe pod    → WHY? (read Events + Conditions at the bottom first)
3. kubectl logs [--previous] → what did the APP say before it died?
4. kubectl exec / debug    → poke the live (or a copy of the) container
```

The mistake beginners make is jumping straight to logs or editing YAML. Start at the
top: the **state** tells you which *class* of problem you have, and the **events**
usually tell you the cause in plain English.

### `kubectl describe`: events and conditions are the system talking

`kubectl describe pod <name>` ends with two gold-mine sections:

- **Conditions** — `PodScheduled`, `Initialized`, `ContainersReady`, `Ready`. The
  first `False` condition tells you how far the Pod got.
- **Events** — a timeline the control plane writes: "Failed to pull image," "0/3
  nodes are available: 3 node(s) had untolerated taint," "Back-off restarting failed
  container," "OOMKilled." This is Kubernetes explaining itself; read it first.

(Events expire after ~1 hour by default. `kubectl get events --sort-by=.lastTimestamp`
shows the namespace-wide timeline.)

### Logs: current and *previous*

`kubectl logs <pod>` shows the current container's output. Two essentials:

- **Crashed/restarted container:** `kubectl logs <pod> --previous` shows the logs from
  the **instance that just died** — often the only place the real error appears
  before a `CrashLoopBackOff`.
- **Multi-container Pod:** `kubectl logs <pod> -c <container>` selects a container (and
  `-c` is required when there's more than one).

### Getting inside: exec, debug, port-forward

- **`kubectl exec -it <pod> -- sh`** — run a shell in a *running* container to inspect
  files, env, and connectivity. (Doesn't work if the container won't start or has no
  shell.)
- **`kubectl debug`** — attach an **ephemeral debug container** (with your tools) to a
  running Pod, or create a **copy** of a crashing Pod with a different command — the
  way to investigate a container that has no shell or won't stay up.
- **`kubectl port-forward <pod|svc> 8080:80`** — tunnel a cluster port to your laptop
  to test a Service or app directly, bypassing ingress.

### The five classic failure modes and their signatures

| State | Usual cause | First look |
|-------|-------------|------------|
| **ImagePullBackOff** / `ErrImagePull` | wrong image name/tag, private registry auth, rate limit | `describe` → Events (pull error) |
| **CrashLoopBackOff** | app exits non-zero: missing config/env, bad command, failed migration | `logs --previous` |
| **OOMKilled** | memory limit lower than real usage (or a leak) | `describe` → `Last State: OOMKilled` |
| **Pending** | no node fits: insufficient resources, unsatisfiable affinity, untolerated taint, unbound PVC | `describe` → Events (scheduler message) |
| **Service returns nothing** | selector doesn't match Pod labels, or Pods not ready | `get endpointslices` (empty?) |

The skill is **matching the signature to the cause**, then confirming with one
targeted command — not trying random fixes.

---

## 2. Why it matters for platform engineering

- **You are the escalation point.** When a team's workload is red and they're stuck,
  it lands on the platform team. A fast, teachable workflow is a core part of the job
  — and something you encode into runbooks and docs for self-service.
- **Most tickets are the same five problems.** Teaching teams to read `describe` and
  `logs --previous` themselves deflects a huge volume of support load — leverage,
  which is the whole point of a platform.
- **Good diagnosis prevents bad fixes.** "Just bump the memory limit" or "give it
  more RBAC" without reading the evidence creates new problems. The workflow keeps
  fixes grounded in what the system actually reported.
- **It validates everything else in this phase.** Every failure mode here maps to a
  concept you've learned: OOMKilled → resources, Pending → scheduling, unreachable →
  Services, CrashLoop → config. Debugging is where the fundamentals pay off.

---

## 3. Mental model

Think of debugging as a **funnel that narrows from "what" to "why" to "proof"** — and
never start in the middle:

```text
   ┌──────────────────────────────────────────────────────────────┐
   │ get pods        → the STATE names the CLASS of problem         │
   ├──────────────────────────────────────────────────────────────┤
   │ describe pod    → Conditions + Events name the CAUSE (read me!)│
   ├──────────────────────────────────────────────────────────────┤
   │ logs --previous → the APP's own last words (for CrashLoop)     │
   ├──────────────────────────────────────────────────────────────┤
   │ exec / debug    → confirm the hypothesis inside the container  │
   └──────────────────────────────────────────────────────────────┘
        each step either answers it or tells you which step is next
```

Rules to remember:

1. **Read the events before touching YAML.** The cluster usually tells you the cause.
2. **`--previous` for anything that restarted.** The live container is the retry, not
   the crash.
3. **Empty EndpointSlice = selector/label or readiness problem**, not a networking
   mystery.

---

## 4. Minimal implementation

Practice the funnel on a deliberately broken Pod. Create one with a bad image:

```bash
kubectl run broken --image=nginx:thistagdoesnotexist
```

Now run the workflow instead of guessing. Step 1 — what state?

```bash
kubectl get pod broken          # STATUS: ImagePullBackOff / ErrImagePull
```

Step 2 — why? The events say it outright:

```bash
kubectl describe pod broken | sed -n '/Events/,$p'
# Events: Failed to pull image "nginx:thistagdoesnotexist": ... not found
```

The signature (`ImagePullBackOff`) plus the event (`not found`) is the diagnosis: a
wrong tag. Fix and confirm:

```bash
kubectl delete pod broken
kubectl run broken --image=nginx:1.27
kubectl get pod broken          # Running
```

You didn't edit anything blindly — the state named the class, the event named the
cause, and one change fixed it. The lab repeats this discipline across all five
failure modes.

---

## 5. Hands-on lab

You'll be handed **five pre-broken manifests** — one each for `OOMKilled`,
`ImagePullBackOff`, `Pending` (untolerated taint), `CrashLoopBackOff` (missing env
var), and an unreachable Service (wrong selector). For each, you'll run the workflow,
diagnose the root cause from the evidence, fix the manifest, and verify. Solutions are
provided in a collapsible block — try each yourself first. Local kind cluster only.

➡️ **[Start the lab: Diagnose and fix five broken workloads](./lab/README.md)**

---

## 6. Production considerations

- **Debugging should be self-service.** Publish the workflow and the five-signature
  table as a runbook so teams fix their own `CrashLoopBackOff` before paging you.
- **Events are ephemeral — ship them.** Default events vanish in ~1 hour. Forward
  events and logs to your observability stack (Phase 11) so you can debug *after* the
  fact, not only live.
- **`kubectl debug` over baking tools into images.** Keep app images minimal
  (distroless, no shell) for security, and attach ephemeral debug containers when you
  need tools — rather than shipping `curl`/`bash` in production images.
- **Restrict interactive access.** `exec` into prod containers is powerful and
  audited; gate it with RBAC ([Module 03.6](../06-rbac/)) and prefer read-only
  investigation (logs, describe, debug copies) where possible.
- **Alert on the signatures.** `OOMKilled`, `CrashLoopBackOff`, and `Pending`
  durations make excellent alerts — they catch the common failures early and point
  straight at the cause.
- **Blameless postmortems.** The same five failures recur across teams; capture fixes
  in shared docs so the whole org learns once.

---

## 7. Common mistakes

- **Jumping to `logs` or editing YAML before `describe`.** — You miss the event that
  states the cause (taint, pull error, scheduling failure). *Fix:* always read
  Conditions + Events first.
- **Forgetting `--previous` on a CrashLooping Pod.** — Current logs show the latest
  retry, which may start cleanly; the fatal error was in the instance that died.
  *Fix:* `kubectl logs <pod> --previous`.
- **Treating OOMKilled as a crash bug.** — Chasing the app code when the container was
  killed for exceeding its memory limit. *Fix:* check `Last State: OOMKilled` in
  `describe`; right-size the memory limit (or fix the leak).
- **Debugging an unreachable Service as a "network problem."** — It's almost always a
  selector/label mismatch or unready Pods, not CNI. *Fix:* check the EndpointSlice is
  non-empty first.
- **Random remediation.** — Bumping limits, adding RBAC, or restarting without
  evidence creates new issues. *Fix:* one hypothesis from the evidence, one targeted
  change, then verify.

---

## 8. Assessment

**Knowledge checks**

1. What are the first two commands you run on *any* broken Pod, and in what order?
2. Why is `kubectl logs --previous` often essential for a `CrashLoopBackOff`?
3. How do you tell `OOMKilled` apart from an ordinary application crash?
4. A Pod is `Pending`. Name three distinct causes and where you'd confirm each.
5. A Service returns nothing though its Pods are `Running`. What's the single most
   likely cause and how do you confirm it?

**Concept exercise**

> Describe your step-by-step approach to any failing workload — **without naming a
> single `kubectl` command.** Explain the "state → cause → proof" funnel in plain
> language, as you would to a new teammate.

**Debugging exercise**

> You run `kubectl get pods` and see one Pod `0/1 CrashLoopBackOff` with 7 restarts.
> `kubectl logs <pod>` prints nothing useful (the container just started again). Walk
> through exactly what you'd do next, and what you expect each command to reveal.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** `kubectl get pods` (state → class of problem), then `kubectl describe pod`
  (read Conditions + Events for the cause).
- **Q2:** The currently running container is a fresh retry that may look fine; the
  error that caused the crash is in the previous, now-dead instance, which
  `--previous` shows.
- **Q3:** `kubectl describe pod` shows `Last State: Terminated, Reason: OOMKilled`
  (and exit code 137). An app crash shows a different reason/exit code and app logs.
- **Q4:** Insufficient resources (requests exceed free capacity), unsatisfiable
  affinity/nodeSelector, an untolerated taint, or an unbound PVC — confirm each in
  `kubectl describe pod` Events (the scheduler message) and `kubectl get pvc`.
- **Q5:** The Service selector doesn't match the Pods' labels (or Pods aren't ready),
  so the EndpointSlice is empty. Confirm with `kubectl get endpointslices
  -l kubernetes.io/service-name=<svc>` and compare `kubectl get pods --show-labels`
  to the Service's selector.
- **Debugging exercise:** `kubectl describe pod <pod>` → read Events and `Last State`
  (OOMKilled? error?); `kubectl logs <pod> --previous` → the dead instance's real
  error (e.g. "config not found," "env not set"); if needed, `kubectl debug` a copy
  with an overridden command, or `exec` once it stays up. Then fix the root cause
  (config/env/limit) and re-apply.

</details>

---

## 9. Further reading

- Kubernetes — [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/)
- Kubernetes — [Debug Pods (Pending, CrashLoopBackOff, …)](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/)
- Kubernetes — [Determine the Reason for Pod Failure](https://kubernetes.io/docs/tasks/debug/debug-application/determine-reason-pod-failure/)
- Kubernetes — [Ephemeral Containers](https://kubernetes.io/docs/concepts/workloads/pods/ephemeral-containers/)
- Kubernetes — [`kubectl` Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 03.8 — Health, Probes and Scheduling](../08-health-and-scheduling/)
· _Next phase:_ [04 · Platform Project 01 →](../../04-platform-project-01/)
