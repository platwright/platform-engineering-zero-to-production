# `shared/terraform-modules/`

Reusable Terraform modules consumed by project and capstone environments.

Planned modules (introduced in **[05 · Infrastructure as Code](../../05-infrastructure-as-code/)**):

```text
gke-cluster/            # a hardened GKE cluster
gke-node-pool/          # reusable node pool (general / spot)
vpc/                    # network + subnets + firewall
gcs-bucket/             # object storage (incl. remote state buckets)
secret-manager-secret/  # a managed secret
```

Each module will follow the standard layout (`main.tf`, `variables.tf`,
`outputs.tf`, `README.md`, `versions.tf`) and be tested with Terratest.

> 🚧 Populated during Phase 4. See the [ROADMAP](../../ROADMAP.md).
