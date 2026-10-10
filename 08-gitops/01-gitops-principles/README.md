# Module 08.1 — GitOps Principles

> GitOps is **operating infrastructure and applications by making Git the single
> source of truth and letting software continuously reconcile reality toward it.**
> This module builds that idea from first principles — the four principles, why
> *pull* beats *push*, and how drift detection and self-healing are just the
> Kubernetes reconciliation loop applied to delivery — before you touch a single
> GitOps tool.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** [Phase 3 · Kubernetes Fundamentals](../../03-kubernetes-fundamentals/) (the reconciliation loop) and a local kind cluster from [`00-orientation`](../../00-orientation/environment-setup.md).

## Learning objectives

By the end of this module you will be able to:

- State the **four OpenGitOps principles** and explain what each one buys you.
- Explain **push-based vs pull-based** delivery and why pull wins for security.
- Describe **drift detection and self-healing** as the reconciliation loop applied
  to delivery, not a new invention.
- Draw the boundary between **CI and CD** — where continuous integration ends and
  GitOps begins.
- Judge **when GitOps adds value and when it adds complexity without value.**

---

## 1. Concept

### What GitOps actually is

GitOps is an operating model with one core move: **describe the entire desired
state of your system declaratively, store that description in Git, and run software
that continuously makes the real system match it.** You stop issuing commands
("create this, scale that") and start editing a desired state that a machine
enforces.

The [OpenGitOps](https://opengitops.dev/) project (a CNCF effort) distills it to
**four principles**. A system is GitOps *only if all four hold*:

- **Declarative.** The whole system is described declaratively — *what* you want,
  not *how* to achieve it. Kubernetes manifests, Helm values, and Kustomize
  overlays are declarative; a shell script full of `kubectl` commands is not.
- **Versioned and immutable.** Desired state is stored so it is versioned,
  immutable, and retains a complete history. Git does this: every state is a commit,
  nothing is overwritten in place, and you can always roll back to a prior commit.
- **Pulled automatically.** Software agents **pull** the declared state from the
  source automatically — nobody pushes changes into the cluster. The cluster reaches
  out for its own config.
- **Continuously reconciled.** Agents continuously observe actual state and
  **reconcile** it toward desired state, correcting drift without human action.

Read those again and notice: the last one is exactly what Kubernetes controllers do
with `spec` and `status`. GitOps is not a new mechanism — it is the reconciliation
loop you already know, with **Git as the declared `spec` for the whole cluster.**

### Push vs pull delivery

There are two ways declared state can reach a cluster:

- **Push (traditional CI/CD).** A pipeline runs *outside* the cluster, authenticates
  *into* it, and pushes changes: `kubectl apply`, `helm upgrade`, `terraform apply`.
  The pipeline needs cluster credentials, and it only acts when it runs — between
  runs, nothing keeps the cluster in line.
- **Pull (GitOps).** An agent runs *inside* the cluster, watches Git, and pulls
  changes in. Credentials to the cluster never leave the cluster; the pipeline never
  touches production. The agent runs constantly, so drift is corrected continuously.

```text
PUSH (CI holds the keys to prod)        PULL (cluster fetches its own state)
────────────────────────────────        ──────────────────────────────────────
  CI runner (public, internet)            Git repo (desired state)
     │  kubectl apply                         ▲   pull
     │  (needs cluster-admin creds)           │
     ▼                                     ┌──┴───────────────┐
  ┌──────────────┐                         │  in-cluster agent │
  │   cluster    │  ◄── creds exfiltrated  │  (holds creds     │
  │ (prod)       │      = cluster owned     │   locally only)  │
  └──────────────┘                         └──┬───────────────┘
                                              ▼ apply
                                           ┌──────────────┐
                                           │   cluster     │
                                           └──────────────┘
```

**Why pull wins for security:** push-based delivery requires long-lived, highly
privileged cluster credentials to live in your CI system — an internet-reachable
target that, if compromised, hands an attacker your production cluster. Pull-based
delivery keeps credentials inside the trust boundary. CI's job shrinks to *build an
image and open a pull request*; it never needs cluster access at all.

### Where CI ends and GitOps (CD) begins

GitOps does **not** replace CI — it replaces the *deploy* half of CI/CD.

```text
  CI (continuous integration)        │   CD via GitOps (continuous delivery)
  ──────────────────────────────     │   ──────────────────────────────────
  build → test → scan → publish      │   update config repo → PR → merge
  image to a registry, then write    │   → agent pulls → reconciles cluster
  the new image tag into the         │   to the declared state
  config repo (a commit/PR)          │
  ───────────────────────────────────┼────────────────────────────────────
         ends at a Git commit         │     starts at that Git commit
```

The handoff is a **commit to the config repository**. CI produces an artifact and
proposes a desired-state change; GitOps takes it from there. This clean seam is
what lets CI stay credential-free.

### Drift detection and self-healing

**Drift** is any divergence between what Git declares and what the cluster runs —
someone ran `kubectl edit`, an operator mutated a field, a node died. A GitOps agent
continuously compares the two and reports the resource as **OutOfSync**. With
**self-healing** enabled, it goes further: it *reverts* the live object back to the
Git-declared state automatically. The 2 a.m. hotfix someone forgot to commit is
undone within seconds — which is exactly the point. The only way to change the
cluster for good is to change Git.

### Config GitOps vs application GitOps, and when to skip it

GitOps applies to two things: **application delivery** (your services' manifests)
and **cluster/infra config** (ingress controllers, RBAC, operators, network
policies). The second is often the bigger win — your cluster's entire configuration
becomes reproducible from Git. But GitOps is not free. It adds a config repository,
an agent to operate, and a promotion workflow. For a solo developer on a throwaway
cluster, `kubectl apply` is fine. GitOps earns its keep when you have **multiple
environments, multiple people, or a need for audit and reproducibility** — i.e.
almost every real platform, and the reason this whole phase exists.

---

## 2. Why it matters for platform engineering

GitOps is the backbone of modern platform delivery, and as a platform engineer you
provide it *as a capability* to every team:

- **Security posture, structurally.** Removing cluster credentials from CI closes
  one of the largest attack surfaces in a delivery pipeline. You get least privilege
  by architecture, not by policy.
- **Audit and compliance for free.** `git log` is your change-management record:
  every production change is a reviewed, signed, reversible commit with an author
  and a reason. Auditors love this; so will you during an incident.
- **Disaster recovery becomes trivial.** If a cluster is lost, you don't restore
  from tribal knowledge — you point a fresh cluster at the repo and it rebuilds
  itself. The repo *is* the backup.
- **Reduced cognitive load (the whole point of the course).** Developers promote by
  opening a pull request, not by learning `kubectl`, cluster endpoints, and
  credentials. The paved road is "edit YAML, open PR."
- **Consistency across teams and clusters.** One model — reconcile to Git — governs
  every environment, so the Nth cluster behaves like the first.

---

## 3. Mental model

Hold one picture for the entire phase: **the reconciliation loop, with Git as the
desired state.** Phase 3 taught you that Kubernetes controllers drive `status`
toward `spec`. GitOps wraps the whole cluster in the same loop and moves the `spec`
into Git.

```text
            ┌──────────────────────────────────────────────┐
            │   Git repository  —  DESIRED STATE            │
            │   declarative manifests, versioned, reviewed  │
            └───────────────────────┬──────────────────────┘
                                    │ 1. observe (poll or webhook)
                                    ▼
   ┌───────────────┐   2. compare  ┌───────────────────────────┐
   │  Live cluster │ ◄──────────── │   GitOps agent (in-cluster)│
   │  ACTUAL state │ ──────────────►│  diff desired vs actual   │
   └──────┬────────┘   4. observe  └─────────────┬─────────────┘
          │                                      │ 3. act: sync if drift
          └──────────────────────────────────────┘
                   a loop that never stops running
```

Three rules to remember a year from now:

1. **Git is the `spec`; the cluster is the `status`.** You edit intent in Git; the
   agent owns convergence.
2. **Nobody pushes to prod.** The cluster pulls its own state, so credentials stay
   inside it.
3. **Drift is temporary by design.** Anything not in Git is reverted; the only
   durable way to change the system is to change Git.

---

## 4. Minimal implementation

Before Argo CD (next module), build the reconcile loop **by hand** so you can see
there's no magic. A GitOps agent is, in essence, this loop:

```bash
# The entire idea of GitOps in five lines. Point it at a Git checkout of manifests.
while true; do
  git -C ./config pull --quiet                 # 1. observe desired state
  kubectl apply -f ./config/manifests/ >/dev/null  # 2+3. compare & converge
  sleep 15                                      # 4. ...then do it again, forever
done
```

That loop satisfies all four principles: the manifests are **declarative**, Git
makes them **versioned and immutable**, the loop **pulls** rather than being pushed
to, and it **continuously reconciles**. Now watch it behave like a real GitOps
system:

```bash
# Introduce drift out-of-band — the kind of thing a 2 a.m. hotfix does:
kubectl scale deployment web --replicas=7
# Within ~15s the loop re-applies the manifest (replicas: 2) and drift vanishes.

# Make a durable change the right way — change the declared state in Git:
sed -i 's/replicas: 2/replicas: 4/' ./config/manifests/web.yaml
git -C ./config commit -am "scale web to 4"
# The next pull brings replicas: 4, and the cluster converges to it.
```

This toy agent is missing everything a real one has — health assessment, pruning,
ordering, a UI, multi-cluster, RBAC — but it is *conceptually complete*. Argo CD is
this loop, done properly. You'll replace the shell script with it in Module 08.2.

---

## 5. Hands-on lab

You'll stand up a local Git repo of manifests and run a hand-written reconcile loop
against a kind cluster, then prove the two behaviours that define GitOps: it heals
out-of-band drift, and it only accepts durable change through a Git commit.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

Moving from the toy loop to a platform capability means handling:

- **Poll vs webhook.** Polling (every N seconds) is simple and robust; webhooks give
  near-instant sync but add a public endpoint to secure. Most teams poll and add
  webhooks later for latency.
- **Repo topology.** Keep **application source** and **deployment config** in
  separate repos. Mixing them creates a loop where a CI build commits a tag, which
  the same repo's CI re-triggers. A dedicated config repo also scopes who can change
  production.
- **Agent RBAC.** The in-cluster agent is powerful — it can apply anything in its
  scope. Give it least privilege per project/namespace, not blanket cluster-admin.
- **Secrets.** Plaintext secrets must never enter Git. This is a big enough topic to
  own Module 08.5 — for now, just know the reconcile loop alone is not a secrets
  story.
- **Observability of sync.** You need to see sync status, drift, and failures, and
  alert on "OutOfSync for >N minutes." A silent agent that stopped reconciling is a
  latent outage.
- **Scale.** One loop per cluster is fine; hundreds of apps across many clusters
  needs generators and a controller built for it (Modules 08.2–08.3).

---

## 7. Common mistakes

- **Calling push-based CI "GitOps" because the manifests live in Git.** Storing YAML
  in Git is necessary but not sufficient; if a pipeline pushes with cluster creds,
  it is not pull-based or continuously reconciled. *Fix:* use an in-cluster agent
  that pulls and reconciles — verify all four principles hold.
- **One repo for app code and deploy config.** CI commits an image tag, which
  re-triggers CI, which commits again — plus everyone who can touch code can now
  touch prod. *Fix:* separate the config repo and scope its access.
- **Leaving self-heal off and calling it GitOps.** Without reconciliation, drift
  accumulates silently and Git stops reflecting reality. *Fix:* enable self-heal (or
  at least alert loudly on drift) so Git stays authoritative.
- **Putting plaintext secrets in Git "temporarily."** Git history is forever; a
  leaked secret in a commit is leaked permanently. *Fix:* never commit secrets —
  use the patterns in Module 08.5 from day one.
- **Adopting GitOps where it adds only overhead.** A solo dev on a scratch cluster
  gains little and pays the operating cost. *Fix:* adopt it when you have multiple
  environments, people, or audit needs — otherwise keep it simple.

---

## 8. Assessment

**Knowledge checks**

1. Name the four OpenGitOps principles. Which one makes a cluster self-healing?
2. Why does pull-based delivery have a smaller attack surface than push-based?
3. Where exactly is the handoff between CI and GitOps-based CD?
4. What is drift, and what does a self-healing agent do when it detects drift?
5. Give one situation where adopting GitOps is *not* worth the complexity.

**Concept exercise**

> Explain GitOps to a skeptical engineer **without naming Argo CD, Flux, or any
> other tool.** Describe the operating model and the four principles so they'd
> recognize a GitOps system by its behavior, not its logo.

**Trade-off / debugging exercise**

> A teammate says: "Our CI runs `kubectl apply` on every merge and all our YAML is
> in Git, so we already do GitOps." List what's missing against the four principles.
> Then: a service keeps reverting to 2 replicas minutes after on-call scales it to
> 8 during an incident. Explain what's happening and the *correct* way to make the
> change stick.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Declarative; versioned and immutable; pulled automatically; continuously
  reconciled. **Continuous reconciliation** provides self-healing.
- **Q2:** Pull keeps cluster credentials inside the cluster; push puts long-lived,
  highly privileged creds in an internet-reachable CI system that becomes a prime
  target.
- **Q3:** At a **commit to the config repository** — CI ends by proposing a
  desired-state change (e.g. a new image tag); GitOps reconciles from there.
- **Q4:** Drift is divergence between Git (desired) and the cluster (actual). A
  self-healing agent reverts the live object back to the Git-declared state.
- **Q5:** A solo developer on a short-lived/scratch cluster: the audit, multi-env,
  and reproducibility benefits don't apply, and the agent/repo/workflow are pure
  overhead.
- **Missing from the "we already do GitOps" claim:** it's push, not pull (CI holds
  creds); it's not continuously reconciled (only on merge); so drift isn't healed.
- **Debugging:** a reconcile loop with self-heal is reverting the manual scale to
  the Git value (2). The correct fix is to change the declared replica count in Git
  (commit/PR), or temporarily pause auto-sync for a deliberate incident override —
  then reconcile Git back to reality.

</details>

---

## 9. Further reading

- OpenGitOps — [Principles v1.0](https://opengitops.dev/) and the [GitOps Glossary](https://github.com/open-gitops/documents)
- CNCF — [What is GitOps?](https://www.cncf.io/blog/2021/09/28/the-cncf-tag-app-delivery-provides-gitops-principles/)
- Argo CD — [Core concepts](https://argo-cd.readthedocs.io/en/stable/core_concepts/)
- Flux — [GitOps and the reconciliation model](https://fluxcd.io/flux/concepts/)
- Weaveworks — [Guide to GitOps](https://www.weave.works/technologies/gitops/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Phase 7 · GitOps overview](../README.md)
· _Next:_ [08.2 — Argo CD Fundamentals →](../02-argocd-fundamentals/)
