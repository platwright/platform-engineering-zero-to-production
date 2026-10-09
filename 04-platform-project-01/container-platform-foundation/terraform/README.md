# Terraform — Pass 2 (provision the cluster as code)

> 🚧 **Pass 2.** In Pass 1 you ran everything on a local `kind` cluster. Here you'll
> replace that with a real, reproducible GKE cluster provisioned by Terraform. You
> build this out in **[Phase 4 · Infrastructure as Code](../../../05-infrastructure-as-code/)**;
> this folder is the home for it.

## Target layout

```text
terraform/
├── modules/          # reusable modules (consume shared/terraform-modules too)
│   ├── gke-cluster/
│   ├── vpc/
│   └── gcs-bucket/   # remote state bucket
└── environments/
    └── dev/          # calls the modules to build the dev foundation
        ├── main.tf
        ├── variables.tf
        ├── backend.tf    # GCS remote backend (state locking)
        └── terraform.tfvars.example
```

## What it must provision (project requirement #1)

- A GKE cluster + VPC + node pools.
- A GCS bucket for **remote, locked** Terraform state.
- Outputs wired so the Kubernetes layer (namespaces, RBAC, quotas) can be applied
  on top — ideally delivered by GitOps (Phase 7), not `kubectl apply` by hand.

## Illustrative shape (you'll flesh this out in Phase 4)

```hcl
terraform {
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
  }
  backend "gcs" {} # configured per environment
}

module "vpc" {
  source = "../../modules/vpc"
  # ...
}

module "gke" {
  source     = "../../modules/gke-cluster"
  network    = module.vpc.network
  subnetwork = module.vpc.subnetwork
  # ...
}
```

> **Cost & safety:** set a budget alert first
> ([cloud account setup](../../../00-orientation/cloud-account-setup.md)), use small
> node sizes and spot where possible, and `terraform destroy` when you're done.
