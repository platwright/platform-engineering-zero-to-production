<!-- markdownlint-disable MD033 -->
# DR runbook — <platform / cluster name>

> The tested, ordered procedure to recover the platform from total cluster/region
> loss. A DR plan is only real once it has been **drilled**. Replace every `<...>`.

**Owner:** `<platform team / role>` · **Last drilled:** `<date>` ·
**Drill cadence:** `<quarterly>`

## Targets

| Service | RTO (max downtime) | RPO (max data loss) | Criticality |
|---------|--------------------|---------------------|-------------|
| Cluster API / control plane | `<e.g. 1h>` | `<provider-managed>` | critical |
| GitOps (Argo CD) + config | `<e.g. 1h>` | `<0 — in Git>` | critical |
| Registry (PV data) | `<e.g. 2h>` | `<e.g. 1h>` | high |
| Platform database (PV data) | `<e.g. 2h>` | `<e.g. 15m>` | high |
| Secrets | `<e.g. 30m>` | `<0 — in vault>` | critical |

## What is re-created vs restored

- **Re-created from source (not backed up):**
  - Cluster infra → `<Terraform repo + apply command>`
  - App & platform config → `<Argo CD re-sync from Git repo URL>`
  - Secret values → `<ESO re-syncs from vault: name/URL>`
- **Restored from backup (not in Git):**
  - Persistent volumes → `<Velero backup location / schedule name>`
  - etcd (self-managed only) → `<snapshot location>`

## Recovery procedure (ordered)

1. **Declare DR + assign roles.** Incident commander: `<role>`. Open the incident
   (Module 17.3) and start the timeline (T0 = `<time>`).
2. **Re-create the cluster.** `<terraform -chdir=... apply>` → fresh cluster in
   `<region>`. Verify API reachable.
3. **Bootstrap GitOps.** Install Argo CD: `<command>`. Point it at `<config repo>`.
4. **Re-sync all config.** Argo CD syncs every app/platform manifest. Verify CRDs and
   operators are present.
5. **Restore stateful data.** `velero restore create --from-backup <name> --wait` for
   `<registry, database>` volumes. Verify data integrity.
6. **Re-sync secrets.** Confirm ESO reconnected to `<vault>` and Secrets are populated.
7. **Verify recovery.** Platform SLOs green (Module 17.2); a test team can deploy.
   Record recovery time (T_recovered − T0) and compare to RTO.
8. **Communicate restored.** Status page + teams notified.

## Verification checklist

- [ ] Cluster API reachable and nodes Ready
- [ ] Argo CD healthy; all Applications Synced/Healthy
- [ ] Persistent data restored and consistent (`<how verified>`)
- [ ] Secrets present and valid
- [ ] Platform SLOs green; test deploy succeeds
- [ ] Recovery time within RTO; last restore point within RPO

## Drill log

| Date | Scenario | Time to recover | RTO met? | RPO met? | Findings / actions |
|------|----------|-----------------|----------|----------|--------------------|
| `<date>` | `<full cluster loss>` | `<e.g. 48m>` | `<yes/no>` | `<yes/no>` | `<action + owner>` |
