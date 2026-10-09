# Module: `service`

A tiny, free stand-in for "provision a service environment". It generates a per-
environment config file and a random token. In production you'd replace the body
with a GKE cluster, node pool, and related resources — **the interface
(`variables.tf` / `outputs.tf`) would stay the same.**

## Usage

```hcl
module "payments" {
  source      = "../../modules/service"
  name        = "payments"
  environment = "prod"
  replicas    = 6
  log_level   = "warn"
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | `string` | — (required) | Service name. |
| `environment` | `string` | — (required) | Environment (dev/staging/prod). |
| `replicas` | `number` | `2` | Desired replicas (1–50, validated). |
| `log_level` | `string` | `"info"` | One of debug/info/warn/error (validated). |

## Outputs

| Name | Description |
|------|-------------|
| `config_path` | Path to the generated config file. |
| `token` | Generated service token (sensitive). |
