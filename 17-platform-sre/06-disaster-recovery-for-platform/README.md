# Module 17.6 — Disaster Recovery for Platform

> Pods fail, nodes fail — you have planned for those. This module plans for the worst:
> an **entire cluster or region is gone.** Disaster recovery is how a platform comes
> back from total loss within a *defined* time and with a *defined* amount of data
> lost — targets called **RTO** and **RPO** — using backups you have actually tested.
> For a platform, "the cluster is gone" must be a rehearsed drill, not a catastrophe.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Phase 8 · GitOps](../../08-gitops/) and
[Phase 5 · IaC](../../05-infrastructure-as-code/) (your recovery relies on both), a
local [kind](https://kind.sigs.k8s.io/) cluster, `kubectl`, and the
[Velero](https://velero.io/) CLI (the lab uses a local MinIO backend — free).

## Learning objectives

By the end of this module you will be able to:

- Define **RTO** and **RPO** and set them for platform services.
- Identify what must be backed up: cluster resources, persistent volumes, etcd, and
  the sources of truth.
- Use **Velero** to back up, schedule, and restore cluster state.
- Explain how **GitOps + IaC** turn cluster recovery into a re-create-and-re-sync.
- Compare **active-active** and **active-passive** multi-region, and run a **DR
  drill**.

---

## 1. Concept

### Disaster recovery is about total loss

Resilience (Modules 17.4–17.5) handles *partial* failure — a pod, a node, a
dependency. **Disaster recovery (DR)** handles *total* loss: a whole cluster deleted,
a region offline, a control plane corrupted, a catastrophic human error that wipes
everything. The question DR answers is simple and brutal:

> If this entire cluster disappeared right now, how fast could the platform be back,
> and how much data would we lose?

For a platform the stakes are maximal — a lost platform cluster takes *every* team's
deploy pipeline, secrets, and config with it. DR is the plan that makes that
survivable.

### RTO and RPO: the two numbers that define DR

Every DR plan is anchored to two targets:

```text
          disaster
             │
   ┌─────────┼──────────────────────────────┐
   │         │                               │
  last     DISASTER                      service
 backup      │                           restored
   │◄─ RPO ─►│◄────────── RTO ──────────────►│
   │         │                               │
 data you    how much data you LOSE      how long you are DOWN
 can afford  (Recovery Point Objective)  (Recovery Time Objective)
 to lose
```

- **RPO — Recovery Point Objective:** the maximum acceptable *data loss*, measured as
  time. An RPO of 1 hour means you back up at least hourly and may lose up to an
  hour's changes. RPO drives **backup frequency**.
- **RTO — Recovery Time Objective:** the maximum acceptable *downtime* — how long from
  disaster to restored service. An RTO of 2 hours means recovery must complete within
  two hours. RTO drives **how automated and rehearsed** your recovery is.

Tighter targets cost more (more frequent backups, warm standby, automation), so you
set them per service by criticality: the cluster API and GitOps controller get tight
RTO/RPO; a non-critical dashboard can tolerate loose ones.

### What to back up (and where the truth lives)

A Kubernetes platform's state is in several places, and DR must cover all of them:

```text
what                         how it's protected                recovery path
───────────────────────────  ────────────────────────────────  ─────────────────────
cluster resources (objects)  Velero backup of the API objects   Velero restore
persistent volumes (data)    Velero volume snapshots / restic    Velero restore
control-plane state (etcd)    etcd snapshot (self-managed)        etcd restore / managed
cluster itself (infra)       IaC in Git (Terraform)              re-apply to re-create
app & platform config        GitOps repo (Argo CD)               re-sync from Git
secrets' source of truth     external vault / secrets manager    ESO re-syncs
```

The crucial insight from everything you have built: **most of your platform's
definition already lives in Git.** If you did GitOps (Phase 8) and IaC (Phase 5), the
cluster's *configuration* is reproducible from source — you do not back it up, you
**re-create** it. What you genuinely must back up is the **stateful data** that is not
in Git: persistent volumes (databases, registries) and, for self-managed clusters,
etcd.

### The GitOps + IaC recovery path

This is why the earlier phases pay off at the worst moment. Recovering a lost platform
cluster becomes a pipeline, not an archaeology dig:

```text
1. RE-CREATE the cluster      → Terraform apply (Phase 5) stands up a fresh cluster
2. BOOTSTRAP GitOps           → install Argo CD (Phase 8)
3. RE-SYNC all config         → Argo CD pulls every app/platform manifest from Git
4. RESTORE stateful data      → Velero restores PVs; ESO re-syncs secrets from vault
5. VERIFY                     → SLOs green, teams can deploy again
```

Steps 1–3 are *reproducible from source* — the entire value of declarative,
Git-backed platforms is that config recovery is deterministic. Only step 4 needs
real backups. A platform built this way has a dramatically smaller DR surface than one
whose state lives in a cluster nobody can rebuild.

### Velero: cluster backup and restore

**Velero** is the standard tool for backing up and restoring Kubernetes *cluster
state*. It:

- backs up **API objects** (namespaces, deployments, configmaps, CRDs, …) by querying
  the API and storing them in object storage (S3/GCS/MinIO);
- backs up **persistent volumes** via snapshots or filesystem backup (restic/Kopia);
- runs **scheduled** backups (a cron) and supports selective **restore** by namespace,
  label, or resource;
- can **migrate** a cluster's workloads to a new cluster — which is exactly a DR
  restore.

Velero is your answer for "restore the stuff that is not in Git" and for fast
namespace-level recovery from human error.

### etcd snapshots (self-managed control planes)

For **self-managed** clusters, the control-plane state lives in **etcd**. A raw
**etcd snapshot** (`etcdctl snapshot save`) captures the entire cluster state at a
point in time and can rebuild a control plane. On **managed** Kubernetes (GKE/EKS/AKS)
the provider runs and backs up etcd for you — you do not snapshot it, you rely on the
provider's control-plane SLA and focus your DR on resources (Velero) and data (PV
snapshots).

### Multi-region: active-active versus active-passive

To survive a whole *region* loss, you run in more than one:

```text
ACTIVE-ACTIVE                         ACTIVE-PASSIVE
both regions serve traffic            one serves; the other is standby
  + near-zero RTO (failover is live)    + simpler, cheaper
  + load shared                         + standby may be "warm" or "cold"
  − complex: data sync, split-brain     − RTO = time to promote the standby
  − most expensive                      − risk the standby is untested/stale
```

Active-active gives the best RTO/RPO at the highest cost and complexity (you must
solve data replication and split-brain); active-passive is simpler and cheaper but
your RTO is however long promotion takes — which is only trustworthy if you **drill**
it.

### DR runbooks and drills: tested, not assumed

A DR plan that has never been executed is a *hypothesis*, and usually a wrong one.
Backups silently fail, restores hit missing dependencies, and the one person who knew
the steps has left. The discipline:

- **Write the DR runbook** — the exact, ordered recovery steps with the RTO/RPO
  targets, who does what, and every command.
- **Drill it regularly** (quarterly is common): actually restore into a scratch
  environment, time it against the RTO, and verify the RPO. A drill that beats the
  target is confidence; one that misses it is a backlog.
- **Treat a failed drill as a finding**, not an embarrassment — that is the entire
  point of drilling before the real disaster.

> The only backup that counts is one you have **restored**. "We have backups" is not a
> DR plan; "we restored last quarter in 48 minutes against a 2-hour RTO" is.

---

## 2. Why it matters for platform engineering

- **The platform is everyone's single point of failure.** A lost platform cluster
  halts every team at once. DR is the difference between a bad afternoon and an
  existential incident — the ultimate expression of the blast-radius argument
  (Module 17.1).
- **It is where GitOps and IaC cash in.** The declarative, Git-backed platform you
  built recovers by re-create-and-re-sync. DR is the proof that those investments were
  about survivability, not just convenience.
- **Untested DR is a liability disguised as safety.** Leadership believes "we have
  backups" means "we are safe." Drills convert that false comfort into a real,
  measured capability — or expose the gap while it is cheap to fix.
- **Regulators and customers increasingly require it.** Defined RTO/RPO and evidence
  of drills are table stakes for many compliance regimes; the platform team usually
  owns this for the whole org.

## 3. Mental model

Think of DR like **insurance with a tested claim process.** RPO is your deductible
(how much loss you accept); RTO is the claim's payout time (how fast you are made
whole). Backups are the policy — worthless unless you have actually filed a claim
(restored) and know it pays out in time.

```text
          ┌──────────── sources of truth (Git) ────────────┐
          │  IaC (Terraform) ....... re-create the cluster  │  ← reproduced, not backed up
          │  GitOps repo (Argo CD) . re-sync all config     │
          └─────────────────────────────────────────────────┘
                              +
          ┌──────────── backups (not in Git) ──────────────┐
          │  Velero ........ cluster objects + volumes      │  ← RPO = backup frequency
          │  etcd snapshot . self-managed control plane     │
          │  vault ......... secrets' source of truth       │
          └─────────────────────────────────────────────────┘
                              │
                    DISASTER (cluster/region lost)
                              │
          re-create ─► bootstrap GitOps ─► re-sync ─► restore data ─► verify
                              │
                    measured against RTO / RPO in a DRILL
```

The durable idea: **reproduce what is in Git, restore what is not, and prove the whole
path with a timed drill — because an untested backup is just a hope.**

## 4. Minimal implementation

The smallest real DR capability is backup-and-restore you have actually run. With
Velero pointed at object storage, a backup and a scheduled backup are one command
each:

```bash
# back up a namespace's resources (and its volumes) now
velero backup create demo-backup --include-namespaces demo

# schedule a daily full backup (this is your RPO lever)
velero schedule create daily-full --schedule="0 2 * * *"
```

Now simulate disaster and recover — the move that turns "we have backups" into "we can
restore":

```bash
# disaster: the namespace (and everything in it) is gone
kubectl delete namespace demo

# recover from the backup
velero restore create --from-backup demo-backup

# verify: the resources are back
kubectl get all -n demo
```

That loop — backup, destroy, restore, verify — is the heart of DR. Scale it up and it
becomes "re-create the cluster from Terraform, re-sync from Git, restore volumes from
Velero," timed against an RTO. The lab runs exactly this loop on a local MinIO backend,
then has you fill in a DR runbook with real RTO/RPO targets.

## 5. Hands-on lab

You will run Velero against a **local MinIO** backend (free, no cloud): back up a
namespace, schedule a recurring backup, **delete the namespace to simulate disaster**,
restore it, and verify. Then you will complete a **DR runbook** with RTO/RPO targets
and the re-create-and-re-sync recovery path.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **Back up to a *different* failure domain.** A backup in the same region/account as
  the cluster dies with it. Store backups in another region (and ideally another
  account) so a region loss does not take the backups too.
- **Encrypt and access-control backups.** A cluster backup contains secrets and
  config — it is as sensitive as the cluster. Encrypt at rest, lock down the bucket,
  and audit access.
- **Test restores, not just backups.** A green backup job proves nothing about
  restorability. Schedule real restore drills; alert on backup *age* and *failure*, and
  track restore time against RTO.
- **Mind what Velero does not cover.** Managed control-plane/etcd is the provider's
  job; in-flight data not yet snapshotted is lost to RPO; external secret *values* come
  from the vault, not the cluster backup. Map every piece of state to an owner.
- **Automate the recovery path.** The re-create (Terraform) and re-sync (Argo CD) steps
  should be scripted so RTO is not gated on tribal knowledge. The GitOps bootstrap is
  the one manual step to rehearse until it is routine.
- **Drill on a schedule and after major changes.** Quarterly, and after anything that
  changes the recovery path (new CRDs, new storage, a cluster upgrade). Document each
  drill's time-to-recover and findings.

## 7. Common mistakes

- **"We have backups" with no tested restore.** — Backups exist but have never been
  restored, so nobody knows if they work or how long recovery takes. *Fix:* regular,
  timed restore drills; the restore is the deliverable, not the backup.
- **No defined RTO/RPO.** — Recovery has no target, so decisions during a disaster are
  improvised. *Fix:* set RTO/RPO per service by criticality and design backups and
  automation to meet them.
- **Backups in the same blast radius.** — Stored in the region/account that just died.
  *Fix:* replicate backups to an independent failure domain.
- **Backing up what is already in Git.** — Elaborate backups of config that GitOps/IaC
  reproduces, while neglecting the stateful data that is *not* in Git. *Fix:* reproduce
  config from source; back up volumes, etcd (self-managed), and secret sources.
- **Ignoring secrets and CRDs in restore.** — Restore the apps but not their CRDs,
  operators, or secret sources, so nothing actually runs. *Fix:* include CRDs/operators
  and re-sync secrets; test the *whole* path end to end.
- **A DR runbook nobody has run.** — Written once, never drilled, out of date by the
  disaster. *Fix:* treat the runbook as living; every drill updates it.

## 8. Assessment

**Knowledge checks**

1. Define RTO and RPO, and say which one drives backup frequency and which drives
   recovery automation.
2. On a GitOps + IaC platform, which parts of a lost cluster do you *re-create* from
   source, and which must you *restore* from backup?
3. What does Velero back up, and what is it *not* responsible for on a managed cluster?
4. Contrast active-active and active-passive multi-region on RTO and cost.
5. Why is "we have backups" not a disaster-recovery plan?

**Concept exercise**

> Explain to an executive the difference between how much data you could lose and how
> long you would be down in a disaster — **without using the abbreviations "RTO" or
> "RPO."** Make them feel why both numbers need a target.

**Trade-off / debugging exercise**

> Your platform runs on managed Kubernetes with all config in Git (Terraform + Argo
> CD) and a registry and a Postgres database on persistent volumes. Design the DR plan:
> what do you back up versus re-create, what RTO/RPO would you set for the cluster
> versus the database, and what exactly would your quarterly drill do to prove it?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** RPO = max acceptable data loss (time) → drives backup frequency. RTO = max
  acceptable downtime → drives how automated/rehearsed recovery is.
- **Q2:** Re-create from source: the cluster infra (Terraform) and all app/platform
  config (Argo CD re-sync from Git). Restore from backup: persistent-volume data
  (registry, databases), self-managed etcd, and secret values from the vault.
- **Q3:** Velero backs up API objects and persistent volumes (snapshots or
  filesystem) to object storage, on a schedule, with selective restore. On managed
  Kubernetes it is not responsible for the control plane/etcd (the provider is) or for
  external secret values (the vault is).
- **Q4:** Active-active: both regions live, near-zero RTO, highest cost/complexity
  (data sync, split-brain). Active-passive: one live + a standby, RTO = promotion time,
  simpler and cheaper but only trustworthy if drilled.
- **Q5:** Because an unrestored backup is a hope — backups fail silently and restores
  hit missing dependencies. Only a tested, timed restore proves the capability.
- **Trade-off:** Re-create cluster + config from Terraform/Argo CD (no backup needed
  for config). Back up the registry and Postgres PVs with Velero (plus Postgres
  logical dumps for a tighter RPO). Cluster RTO can be moderate (re-create + re-sync is
  deterministic); the database needs a tighter RPO (frequent backups/WAL) because its
  data is not in Git. The quarterly drill: spin up a scratch cluster from Terraform,
  bootstrap Argo CD, re-sync, restore the PVs from Velero, bring up Postgres and the
  registry, and time the whole path against the RTO while verifying the last restorable
  point against the RPO.

</details>

## 9. Further reading

- Velero — [Documentation](https://velero.io/docs/) and
  [How Velero works](https://velero.io/docs/main/how-velero-works/)
- Google — [SRE Workbook: Data Processing Pipelines & DR](https://sre.google/workbook/table-of-contents/)
  and the DiRT (Disaster Recovery Testing) practice
- Kubernetes — [Backing up an etcd cluster](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#backing-up-an-etcd-cluster)
- AWS — [Disaster recovery of workloads: RTO/RPO and strategies](https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-options-in-the-cloud.html)
- CNCF — [Velero project](https://www.cncf.io/projects/velero/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [17.5 — Chaos Engineering for Platforms](../05-chaos-engineering-for-platforms/)
· _Next:_ [Phase 14 — FinOps and Cost Engineering →](../../18-finops-and-cost-engineering/)
