#!/usr/bin/env bash
# Velero install / schedule / backup / restore — reference commands for the DR lab.
# Backend: the local MinIO from minio-deployment.yaml (no cloud account needed).
# Run these one block at a time; read the lab README for the full walkthrough.
set -euo pipefail

# --- 0. Credentials file for the MinIO (S3-compatible) backend -----------------
# Velero reads S3 credentials from a file. These match minio-deployment.yaml.
cat > credentials-velero <<'EOF'
[default]
aws_access_key_id = minio
aws_secret_access_key = minio123
EOF

# --- 1. Install Velero, pointing at the in-cluster MinIO ------------------------
# Requires the `velero` CLI (https://velero.io/docs/) and the MinIO backend running.
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.10.1 \
  --bucket velero \
  --secret-file ./credentials-velero \
  --use-volume-snapshots=false \
  --use-node-agent \
  --backup-location-config region=minio,s3ForcePathStyle=true,s3Url=http://minio.velero.svc:9000

# wait until Velero is ready
kubectl -n velero rollout status deploy/velero --timeout=180s

# --- 2. Back up a namespace NOW -------------------------------------------------
velero backup create demo-backup --include-namespaces demo --wait
velero backup describe demo-backup --details

# --- 3. Schedule a recurring backup (this is your RPO lever) --------------------
# Daily full backup at 02:00; adjust the cron to tighten/loosen RPO.
velero schedule create daily-full --schedule="0 2 * * *" --include-namespaces demo

# --- 4. Simulate disaster: destroy the namespace -------------------------------
kubectl delete namespace demo
kubectl get namespace demo || echo "demo is gone (disaster simulated)"

# --- 5. Restore from the backup -------------------------------------------------
velero restore create demo-restore --from-backup demo-backup --wait
velero restore describe demo-restore

# --- 6. Verify recovery ---------------------------------------------------------
kubectl get all -n demo
