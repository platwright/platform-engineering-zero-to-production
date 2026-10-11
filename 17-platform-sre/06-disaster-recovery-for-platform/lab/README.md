# Lab — Back up and restore the platform with Velero

> You will run the full disaster-recovery loop on a local cluster with **no cloud
> account**: stand up a MinIO object-storage backend, install Velero, back up a
> namespace, schedule recurring backups, **delete the namespace to simulate disaster**,
> restore it, and verify. Then you complete a **DR runbook** with RTO/RPO targets and
> the re-create-and-re-sync recovery path.

**Estimated time:** ~55–75 minutes
**Type:** Build
**Deliverable:** A verified Velero restore and a completed
[`dr-runbook-template.md`](./dr-runbook-template.md).

## Objectives

- Configure Velero against a local (MinIO) backup target.
- Create an on-demand backup and a scheduled backup.
- Restore from backup after simulating total loss, and verify.
- Record RTO/RPO targets and the recovery path in a DR runbook.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, [kind](https://kind.sigs.k8s.io/), and `kubectl`.
- The [Velero CLI](https://velero.io/docs/main/basic-install/) installed locally
  (`velero version` works).
- [Module 17.6](../README.md) theory.
- Starter files in this folder:
  [`minio-deployment.yaml`](./minio-deployment.yaml),
  [`velero-commands.sh`](./velero-commands.sh), and
  [`dr-runbook-template.md`](./dr-runbook-template.md).

## Steps

1. **Create a cluster and the MinIO backend.** MinIO is a local, S3-compatible store
   so Velero needs no cloud:

   ```bash
   kind create cluster --name pe-dr
   kubectl apply -f minio-deployment.yaml
   kubectl -n velero rollout status deploy/minio --timeout=120s
   kubectl -n velero wait --for=condition=complete job/minio-setup --timeout=120s
   # the setup job creates the `velero` bucket
   ```

2. **Create something to protect.** A namespace with real resources is your stand-in
   for platform state:

   ```bash
   kubectl create namespace demo
   kubectl -n demo create deployment web --image=registry.k8s.io/e2e-test-images/agnhost:2.47 -- /agnhost serve-hostname
   kubectl -n demo create configmap app-config --from-literal=greeting=hello
   kubectl -n demo scale deployment/web --replicas=2
   kubectl -n demo get all,configmap
   ```

3. **Create the Velero credentials and install Velero.** The credentials match the
   MinIO deployment:

   ```bash
   cat > credentials-velero <<'EOF'
   [default]
   aws_access_key_id = minio
   aws_secret_access_key = minio123
   EOF

   velero install \
     --provider aws \
     --plugins velero/velero-plugin-for-aws:v1.10.1 \
     --bucket velero \
     --secret-file ./credentials-velero \
     --use-volume-snapshots=false \
     --backup-location-config region=minio,s3ForcePathStyle=true,s3Url=http://minio.velero.svc:9000
   kubectl -n velero rollout status deploy/velero --timeout=180s
   velero backup-location get   # PHASE should be Available
   ```

   (All the commands in this step are collected in
   [`velero-commands.sh`](./velero-commands.sh) for reference.)

4. **Back up the namespace now.** This is your recovery point:

   ```bash
   velero backup create demo-backup --include-namespaces demo --wait
   velero backup describe demo-backup --details
   ```

5. **Schedule recurring backups.** The cron frequency *is* your RPO lever:

   ```bash
   velero schedule create daily-full --schedule="0 2 * * *" --include-namespaces demo
   velero schedule get
   ```

6. **Simulate disaster.** Destroy the namespace and everything in it:

   ```bash
   kubectl delete namespace demo
   kubectl get namespace demo || echo "demo is gone — disaster simulated"
   ```

7. **Restore and time it.** Note the start time (this is your RTO stopwatch), restore,
   and verify the resources are back:

   ```bash
   date -u +"%Y-%m-%dT%H:%M:%SZ"      # RTO start
   velero restore create demo-restore --from-backup demo-backup --wait
   velero restore describe demo-restore
   kubectl get all,configmap -n demo  # web Deployment + app-config are back
   date -u +"%Y-%m-%dT%H:%M:%SZ"      # RTO end
   ```

8. **Complete the DR runbook.** Open [`dr-runbook-template.md`](./dr-runbook-template.md)
   (copy it first) and fill in: RTO/RPO per service, what you **re-create** from Git
   (Terraform cluster + Argo CD config) versus **restore** from Velero (the volumes),
   the ordered recovery procedure, and a **drill log** row with the recovery time you
   just measured. This document is the deliverable — a backup without a runbook is a
   hope.

## Expected result

`velero backup-location get` shows `Available`; `demo-backup` completes with resources
counted; deleting the namespace removes everything; `demo-restore` brings the `web`
Deployment (scaled to 2) and the `app-config` ConfigMap back, confirmed by
`kubectl get`. Your DR runbook has concrete RTO/RPO targets, a clear re-create-vs-
restore split, and a drill-log entry with your measured recovery time.

## Cleanup

> Tear down the cluster and remove the credentials file. Never skip this.

```bash
kind delete cluster --name pe-dr
rm -f credentials-velero
# optional: remove your runbook working copy
# rm -f my-dr-runbook.md
```

## Reflection

- You restored config *and* data here. On a real GitOps + IaC platform, which of these
  steps would you **not** need a backup for, and why?
- Your backup lived in MinIO *inside the same cluster*. Why is that fatal for real DR,
  and where should production backups live?
- The restore took some measured time. If that exceeded your RTO, what are the first
  two things you would automate to shrink it?

## Stretch goals (optional)

- Add a PersistentVolumeClaim to the `demo` namespace, enable Velero's file-system
  backup (`--use-node-agent` and a `backup.velero.io/backup-volumes` annotation), and
  confirm the *data* is restored, not just the PVC object.
- Restore into a **different** namespace with `--namespace-mappings demo:demo-dr` to
  practice recovering alongside a running environment.
- Script the whole loop (backup → delete → restore → verify) and assert success, turning
  your DR drill into an automated, repeatable test.
