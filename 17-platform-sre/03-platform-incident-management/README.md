# Module 17.3 — Platform Incident Management

> When the platform breaks, every team is watching and the pressure is high. The
> difference between a chaotic scramble and a calm recovery is **process**: a clear
> severity scale, one person in command, disciplined communication, a runbook for the
> failure mode, and a blameless postmortem that makes the next incident less likely.
> This module gives you that process and applies it to a real platform failure.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 17.2](../02-platform-slos/) (burn-rate alerts detect the
incident), the [Project 2](../../09-platform-project-02/) Argo CD platform, a local
[kind](https://kind.sigs.k8s.io/) cluster, and `kubectl`.

## Learning objectives

By the end of this module you will be able to:

- Run the **incident lifecycle** — detect, triage, mitigate, resolve, learn — for a
  platform failure.
- Classify platform incidents by **severity (P0–P3)** based on how many teams are
  blocked.
- Assign and perform the **incident commander** and supporting roles.
- Communicate during an incident across **status page, chat, and email**.
- Write a **blameless, structured, action-tracked postmortem**.

---

## 1. Concept

### The incident lifecycle

An incident is any unplanned degradation of a platform service against its SLO. The
response follows a fixed lifecycle so nobody has to invent the steps under pressure:

```text
DETECT → TRIAGE → MITIGATE → RESOLVE → LEARN
  │        │         │          │         │
  │        │         │          │         └─ blameless postmortem, action items
  │        │         │          └─ confirm SLO recovered, close incident
  │        │         └─ stop the bleeding (restore service) BEFORE root cause
  │        └─ scope & impact: how many teams? which capability? assign severity + IC
  └─ a burn-rate alert fires (Module 17.2), not a human noticing
```

The order matters. **Mitigate before you diagnose:** restore service first (roll
back, restart, fail over) and find the root cause later. Teams need the platform
working; the forensic analysis belongs in the postmortem, not the outage.

### Severity: how many teams are blocked?

For a platform, severity is defined by **blast radius** (Module 17.1) — the number of
teams affected and how badly:

```text
sev  name           meaning                                    example
───  ─────────────  ─────────────────────────────────────────  ─────────────────────────
P0   critical       ALL teams blocked; core capability down     cluster API server down;
                                                                 Argo CD cannot sync at all
P1   major          a major capability degraded for many teams   secret propagation failing;
                                                                 builds failing org-wide
P2   partial        partial degradation; a subset affected       one cluster's ingress slow;
                                                                 portal read-only
P3   minor          minor issue, workaround exists, low urgency   a dashboard stale;
                                                                 non-critical addon flaky
```

Severity drives the response: a **P0 pages immediately**, pulls in an incident
commander, and opens a status-page incident; a **P3** is a ticket handled in business
hours. Classify early and re-classify as you learn — it is normal to open at P1 and
downgrade once you understand the scope.

### The incident commander and supporting roles

Under pressure, the biggest failure mode is **everyone debugging and nobody
coordinating**. The fix is explicit roles, borrowed from emergency response:

- **Incident Commander (IC)** — owns the incident, not the fix. Decides, delegates,
  keeps the timeline, and protects the responders' focus. The IC may not touch a
  terminal at all; their job is coordination and decisions.
- **Operations / subject expert** — the person(s) actually running commands to
  mitigate, directed by the IC.
- **Communications lead** — owns updates to teams and stakeholders (status page,
  chat, email) so the IC and ops are not interrupted to answer "any update?".
- **Scribe** (often the IC early on) — records the timeline: every action, time, and
  observation, for the postmortem.

On a small platform team one person may wear several hats, but the **IC role must
always be named and known** — "who is the IC?" should have an instant answer. The IC
is a role, not a rank: a junior engineer can command an incident a principal is
debugging.

### Communication during the incident

Your users are other teams, and silence is corrosive — teams that hear nothing assume
the worst and flood your channels. Communicate on three surfaces:

```text
surface       audience              cadence              content
────────────  ───────────────────  ───────────────────  ────────────────────────────
status page   all teams / org       on change + regular   service, impact, severity, ETA
chat (Slack)  responders + teams    live                  coordination + quick updates
email         leadership / wide     at start, resolve     summary, impact, next steps
```

Rules that keep comms useful under stress:

- **Say impact, not internals.** "Deploys are paused platform-wide; no data loss;
  next update in 30 min" beats "the webhook TLS cert expired on repo-server."
- **Promise the next update time, every time.** A predictable "next update at 14:30"
  stops the stream of "any news?" interruptions.
- **One voice.** The comms lead publishes; responders do not freelance updates.

### Runbooks: every failure mode has one

A **runbook** is a short, tested document for a specific failure: symptoms, how to
confirm it, how to mitigate, and how to verify recovery. The SRE standard is blunt —
**every known failure mode must have a runbook**, linked from the alert that detects
it (notice the `runbook:` annotation on the SLO alerts in Module 17.2).

A runbook turns a 3 a.m. page from "improvise under stress" into "follow the steps."
It is also toil reduction (Module 17.1): a repeated manual recovery is a runbook today
and an automated remediation tomorrow. Runbooks are living documents — every incident
either used a runbook (improve it) or revealed a missing one (write it).

### The postmortem: blameless, structured, action-tracked

After every significant incident you write a **postmortem**. Three properties make it
worth the effort:

- **Blameless.** It examines *systems and conditions*, never "who messed up." People
  act reasonably given the information and tools they had; if a single human error
  could take down the platform, the *system* allowed it — that is the finding. Blame
  kills the honesty that postmortems depend on.
- **Structured.** A fixed template (timeline, impact, contributing factors, what went
  well, action items) so they are comparable and nothing is skipped.
- **Action-tracked.** Every action item has an **owner and a due date**, and is
  tracked to completion like any other work. A postmortem whose actions are never done
  is theatre — the same incident will recur.

> The goal is not to assign fault; it is to **change the system so the next incident
> is less likely or less severe.** A culture that blames individuals gets quieter
> incidents and worse outages; a blameless culture gets honesty and real fixes.

---

## 2. Why it matters for platform engineering

- **Your incidents are everyone's incidents.** A calm, well-run platform incident
  limits org-wide damage; a chaotic one amplifies it. Process is the multiplier that
  works in your favor instead of against you.
- **Trust is won or lost during incidents.** Teams forgive outages; they do not
  forgive silence and surprises. Disciplined comms keep the platform a product teams
  trust even on its worst day.
- **Postmortems compound reliability.** Each action item removes a failure mode or
  adds a runbook. Over time this is how a platform gets genuinely reliable — not by
  never failing, but by never failing the *same way twice*.
- **It connects the whole phase.** Burn-rate alerts (17.2) detect, runbooks mitigate,
  postmortems feed toil reduction (17.1), capacity (17.4), and chaos (17.5). Incident
  management is where platform SRE comes together.

---

## 3. Mental model

Think of an incident as an **aircraft emergency**: one pilot flying (ops), one
captain commanding and talking to the tower (IC + comms), a **checklist** (runbook),
and a **flight recorder** (timeline) you read afterward to prevent the next one.

```text
   ALARM (burn-rate alert)
        │
        ▼
   CAPTAIN takes command  ──►  "I am Incident Commander"   (coordination, not keyboard)
        │
        ├─ assigns severity by blast radius (P0..P3)
        ├─ directs OPS to run the CHECKLIST (runbook) → stop the bleeding
        ├─ COMMS keeps the tower (teams) informed on a fixed cadence
        └─ SCRIBE records the flight recorder (timeline)
        │
        ▼
   LAND SAFELY (SLO recovers) → close incident
        │
        ▼
   READ THE RECORDER (blameless postmortem) → change the system → fewer alarms
```

The durable idea: **mitigate first, coordinate always, blame never, and feed every
lesson back into the system.**

---

## 4. Minimal implementation

The smallest real incident process is three artifacts: a way to **declare**, a
**runbook** to mitigate, and a **template** to learn. Declaring can be as simple as a
chat command that names the IC and severity:

```text
/incident declare
  title:    Argo CD not syncing (deploys paused platform-wide)
  severity: P1
  ic:       @alex
  channel:  #inc-argocd-sync
  status:   https://status.internal.example.com/incidents/1042
```

The runbook it points to is a few decisive steps, not an essay:

```text
RUNBOOK: Argo CD sync failing
  CONFIRM : burn-rate alert "GitOpsSyncLatency" or "ArgoCDApiAvailability" firing;
            `kubectl -n argocd get applications` shows apps stuck/OutOfSync.
  DIAGNOSE: `kubectl -n argocd logs deploy/argocd-repo-server`  (TLS? webhook? repo?)
            `kubectl -n argocd get events --sort-by=.lastTimestamp`
  MITIGATE: restart the controller to clear the stuck state:
            `kubectl -n argocd rollout restart deploy/argocd-application-controller`
            if a bad config was pushed, revert the Git commit (GitOps rolls back).
  VERIFY  : apps return to Synced/Healthy; burn-rate alert clears.
  ESCALATE: if not recovered in 15 min, raise severity and page platform lead.
```

That is enough to run an incident calmly. The lab walks this exact flow against a real
Argo CD, and you capture the outcome in the postmortem template.

```bash
# detect: which apps are not syncing?
kubectl -n argocd get applications -o wide
# mitigate: clear stuck controller state
kubectl -n argocd rollout restart deploy/argocd-application-controller
```

---

## 5. Hands-on lab

You will run a **simulated platform incident** end to end: break Argo CD syncing,
detect it the way the platform does (a burn-rate signal / stuck applications), triage
and assign severity, execute the runbook to mitigate, confirm recovery, and write a
blameless postmortem using the provided template.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **Name the IC instantly.** The single most valuable incident habit is that "who is
  the IC?" always has an answer. Rotate the role and train people into it; it is a
  skill, not a title.
- **Automate declaration.** A `/incident` bot that spins up a channel, a status-page
  entry, and a timeline doc removes toil and ensures consistency at the worst moment.
- **Keep runbooks next to the alert.** The alert that fires should link the runbook
  that fixes it (the `runbook:` annotation from 17.2). A runbook nobody can find
  during a page does not exist.
- **Separate mitigation from root cause.** Train responders to restore service first.
  Heroic live debugging while teams are down is the wrong instinct — roll back, then
  investigate.
- **Track action items like product work.** Postmortem actions go in the same backlog
  with owners and due dates, and are reviewed until done. Unclosed actions are how the
  same incident recurs.
- **Run postmortems for near-misses too.** An alert that nearly breached, a mitigation
  that barely worked — these are free lessons without the damage. Harvest them.

## 7. Common mistakes

- **No incident commander — everyone debugging at once.** — The response is
  uncoordinated, actions collide, and nobody talks to teams. *Fix:* name an IC
  immediately whose job is coordination, not the keyboard.
- **Diagnosing before mitigating.** — Responders chase root cause while teams stay
  down. *Fix:* stop the bleeding first (roll back/restart/fail over); diagnose in the
  postmortem.
- **Silence toward teams.** — Users hear nothing, assume the worst, and flood the
  channel. *Fix:* a comms lead posting impact and a next-update time on a fixed
  cadence.
- **Blameful postmortems.** — The write-up names a culprit, so next time people hide
  details. *Fix:* examine the system and conditions; a single human error that can
  break the platform is a *system* finding.
- **Action items with no owner or date.** — The postmortem is filed and nothing
  changes. *Fix:* every action has an owner and due date, tracked to done.
- **Severity inflation or paralysis.** — Everything is a P0 (alert fatigue) or nothing
  is (slow response). *Fix:* classify by teams-blocked blast radius and re-classify as
  you learn.

## 8. Assessment

**Knowledge checks**

1. Put the incident lifecycle phases in order and state why *mitigate* comes before
   finding root cause.
2. How is platform incident severity (P0–P3) defined, and what distinguishes a P0
   from a P1?
3. What does the incident commander own — and what do they deliberately *not* do?
4. Name the three communication surfaces in an incident and the audience for each.
5. What are the three properties of a good postmortem, and why is "blameless"
   non-negotiable?

**Concept exercise**

> Explain to a new engineer why the person in charge of an incident should usually
> *not* be the one typing commands — **without using the words "incident commander."**

**Trade-off / debugging exercise**

> During a P1 (deploys paused org-wide), an engineer is 20 minutes into live-debugging
> the root cause of an Argo CD sync failure while 40 teams wait. A rollback of the last
> platform commit would very likely restore service in 2 minutes but would lose the
> evidence of *why* it broke. What do you do, and how does the incident process justify
> it?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Detect → triage → mitigate → resolve → learn. Mitigate first because teams
  need the platform working; root-cause forensics belong in the postmortem, not the
  outage.
- **Q2:** By blast radius — how many teams are blocked and how badly. P0 = all teams
  blocked / core capability down; P1 = a major capability degraded for many teams but
  not total.
- **Q3:** The IC owns the incident — coordination, decisions, delegation, timeline,
  comms direction — and deliberately does *not* get absorbed in running the fix
  themselves.
- **Q4:** Status page (all teams/org), chat (responders + teams, live coordination),
  email (leadership/wide, start and resolution summaries).
- **Q5:** Blameless, structured, action-tracked. Blameless is non-negotiable because
  blame destroys the honesty postmortems rely on; you want people to surface details,
  not hide them, so you can fix the system.
- **Trade-off:** Roll back now. The incident process says mitigate before diagnose —
  40 teams blocked outweighs preserving evidence. Capture what you can first (grab the
  repo-server logs, note the bad commit SHA and timestamps for the postmortem), then
  revert to restore service, and reproduce the failure safely afterward in a non-prod
  environment. The postmortem, not the live outage, is where root cause is found.

</details>

## 9. Further reading

- Google — [SRE Book: Managing Incidents](https://sre.google/sre-book/managing-incidents/)
- Google — [SRE Book: Postmortem Culture: Learning from Failure](https://sre.google/sre-book/postmortem-culture/)
- Google — [SRE Workbook: Incident Response](https://sre.google/workbook/incident-response/)
- Atlassian — [Incident management handbook](https://www.atlassian.com/incident-management)
- PagerDuty — [Incident Response documentation](https://response.pagerduty.com/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [17.2 — Platform SLOs](../02-platform-slos/)
· _Next:_ [17.4 — Platform Capacity Planning →](../04-platform-capacity-planning/)
