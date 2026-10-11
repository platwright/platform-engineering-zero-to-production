# Lab — Run a simulated platform incident

> You will run a platform incident end to end on a local cluster. You will install
> Argo CD, establish a healthy steady state, **break syncing** (a misconfiguration
> that takes the repo-server offline — deploys paused platform-wide), then detect,
> triage, assign severity, execute a **runbook** to mitigate, verify recovery, and
> write a **blameless postmortem**. Everything runs free on kind.

**Estimated time:** ~60–75 minutes
**Type:** Build / debug
**Deliverable:** A completed [`postmortem-template.md`](./postmortem-template.md) for
the incident, and the [`runbook-argocd-sync-failure.md`](./runbook-argocd-sync-failure.md)
you followed (and improved).

## Objectives

- Detect a platform incident from its symptoms (stuck Applications / a burn signal).
- Triage scope and impact and assign a severity.
- Execute a runbook to mitigate and restore service.
- Write a blameless, structured, action-tracked postmortem.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, [kind](https://kind.sigs.k8s.io/), and `kubectl`.
- [Module 17.3](../README.md) theory.
- Starter files in this folder:
  [`runbook-argocd-sync-failure.md`](./runbook-argocd-sync-failure.md) and
  [`postmortem-template.md`](./postmortem-template.md).
- Network access to pull the Argo CD manifest and the public example app repo.

## Steps

1. **Create a cluster and install Argo CD.** This is the Project 2 platform in
   miniature:

   ```bash
   kind create cluster --name pe-incident
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.4/manifests/install.yaml
   kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=180s
   kubectl -n argocd rollout status deploy/argocd-application-controller --timeout=180s 2>/dev/null \
     || kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=180s
   ```

2. **Deploy a sample Application and reach steady state.** Point Argo CD at the public
   guestbook example and let it sync:

   ```bash
   kubectl apply -n argocd -f - <<'EOF'
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: guestbook
     namespace: argocd
   spec:
     project: default
     source:
       repoURL: https://github.com/argoproj/argocd-example-apps.git
       targetRevision: HEAD
       path: guestbook
     destination:
       server: https://kubernetes.default.svc
       namespace: default
     syncPolicy:
       automated: {}
   EOF

   # steady state: wait until the app is Synced/Healthy
   kubectl -n argocd get application guestbook -o wide
   ```

   Record this as your **steady state** — `guestbook` is `Synced` and `Healthy`. This
   is what "normal" looks like (you will formalize steady state in Module 17.5).

3. **Inject the fault (start the incident).** Simulate a misconfiguration that takes
   the repo-server offline, so Argo CD can no longer render manifests and **all**
   syncs stall:

   ```bash
   # note the time — this is T0 for your timeline
   date -u +"%Y-%m-%dT%H:%M:%SZ"
   kubectl -n argocd scale deploy/argocd-repo-server --replicas=0
   # force a refresh so the app tries (and fails) to sync
   kubectl -n argocd annotate application guestbook argocd.argoproj.io/refresh=hard --overwrite
   ```

4. **Detect and confirm.** Observe the symptoms a responder would see. In a full stack
   the `ArgoCDApiAvailability` / `GitOpsSyncLatency` burn-rate alert from Module 17.2
   fires; here you confirm via the API objects:

   ```bash
   kubectl -n argocd get application guestbook -o wide
   # expect ComparisonError / Unknown — syncs are failing
   kubectl -n argocd describe application guestbook | grep -A3 -i "condition\|message"
   ```

5. **Triage and declare.** Open [`postmortem-template.md`](./postmortem-template.md)
   (copy it first) and fill in the header: title, **severity**, incident commander,
   and start the **timeline** with your T0. Decide the severity using the blast-radius
   scale — all apps are failing to sync, so this is **P1** (a major capability,
   deploys, is degraded for every team; it is not a full cluster-API P0).

   ```bash
   cp postmortem-template.md incident-2042-argocd-sync.md
   ```

6. **Execute the runbook.** Open [`runbook-argocd-sync-failure.md`](./runbook-argocd-sync-failure.md)
   and follow it: confirm the symptom, diagnose, and identify the repo-server as the
   failed component:

   ```bash
   kubectl -n argocd get deploy argocd-repo-server          # 0/0 — found it
   kubectl -n argocd get events --sort-by=.lastTimestamp | tail -n 15
   ```

7. **Mitigate.** Restore the repo-server (the runbook's mitigation step) and clear the
   stuck state:

   ```bash
   kubectl -n argocd scale deploy/argocd-repo-server --replicas=1
   kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=120s
   kubectl -n argocd annotate application guestbook argocd.argoproj.io/refresh=hard --overwrite
   ```

8. **Verify recovery and close.** Confirm the SLI recovered — `guestbook` returns to
   `Synced`/`Healthy` — and record the resolution time in your timeline:

   ```bash
   kubectl -n argocd get application guestbook -o wide
   date -u +"%Y-%m-%dT%H:%M:%SZ"
   ```

9. **Write the postmortem.** Finish `incident-2042-argocd-sync.md`: the full timeline,
   impact (teams blocked, duration), **contributing factors** (why did a repo-server
   outage stop all syncs? no redundancy? no runbook link on the alert?), what went
   well, and **action items with an owner and due date** (e.g. run repo-server with 2
   replicas; add a `runbook:` annotation to the alert; add a readiness-based auto-
   restart). Keep it blameless — examine the system, not a person.

## Expected result

`guestbook` goes `Synced → ComparisonError/Unknown` when the repo-server is scaled to
zero, and returns to `Synced/Healthy` after you restore it. Your postmortem document
contains a timestamped timeline from T0 to resolution, a severity (P1) justified by
blast radius, blameless contributing factors, and at least two action items each with
an owner and a due date.

## Cleanup

> Tear down the cluster so nothing lingers. Never skip this.

```bash
kind delete cluster --name pe-incident
# optional: remove your working copy
# rm -f incident-2042-argocd-sync.md
```

## Reflection

- You mitigated by restoring the component *before* finding why it was misconfigured.
  Why is that the right order when every team's deploys are paused?
- Which of your action items would have **prevented** this incident, and which only
  make the next one **faster to resolve**? A good postmortem produces both.
- The alert that should have detected this had no runbook link. How does the
  `runbook:` annotation from Module 17.2 change a 3 a.m. page?

## Stretch goals (optional)

- Add the Module 17.2 Argo CD SLO rules to a `kube-prometheus-stack` on this cluster
  and watch the burn-rate alert actually move during the outage.
- Practice the **comms**: write the three status-page updates you would post (declared,
  mitigating, resolved) with impact and a next-update time, no internals.
- Re-run the incident but injure a *different* component (scale the application
  controller to zero). Does your runbook still apply? Update it — runbooks are living
  documents.
