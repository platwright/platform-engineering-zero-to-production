# `shared/helm-charts/`

Platform-standard Helm charts reused across modules and projects.

Planned charts (introduced in **[07 · Kubernetes Package Management](../../07-kubernetes-package-management/)**):

```text
platform-app/     # a hardened application chart:
                  #   deployment, service, hpa, pdb, serviceaccount,
                  #   networkpolicy, values.schema.json, helm tests
```

The `platform-app` chart becomes the basis for golden-path service templates in
the IDP phase.

> 🚧 Populated during Phase 6. See the [ROADMAP](../../ROADMAP.md).
