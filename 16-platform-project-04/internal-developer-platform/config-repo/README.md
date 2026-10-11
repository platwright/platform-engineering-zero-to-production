# config-repo — how a scaffolded service reaches production

> A golden-path template produces a service repo **and** a GitOps overlay. This note
> explains where that overlay goes: into the **Project 2 config repo**, where ArgoCD
> picks it up and deploys it. The IDP doesn't re-implement delivery — it feeds the
> GitOps platform you already built.

## The hand-off

```text
   Backstage template scaffolds a service
        │   its skeleton includes a gitops/ overlay (kustomization + deployment)
        ▼
   The overlay is added to the Project 2 config repo at:
        apps/<team>/<service>/overlays/dev/
        │
        ▼
   Project 2's ApplicationSet (git directory generator) sees the new folder and
   generates an ArgoCD Application → dev auto-syncs → the service is running.
```

This is exactly the [Project 2](../../../09-platform-project-02/) flow. The template's
`gitops/` output matches the shape Project 2's ApplicationSets expect
(`apps/*/*/overlays/<env>`), so **no new ArgoCD wiring is needed** — adding a service is
adding a folder, and the platform does the rest.

## Two ways the overlay lands there

- **Pass 1 (manual, local):** copy the scaffolded `gitops/` folder into your local
  clone of the Project 2 config repo under `apps/<team>/<service>/overlays/dev/`, commit,
  and push. ArgoCD deploys it.
- **Pass 2 (automated):** the template adds a scaffolder step that opens a **pull
  request** to the config repo with the overlay (and CI later updates the image digest).
  This is the fully self-service path — no human copies folders.

## Promotion

Once in the config repo, the service follows the platform's normal promotion flow
(dev auto-sync → staging → prod manual gate) from
[Project 2's build guide](../../../09-platform-project-02/gitops-platform/build-guide.md).
The developer never learned ArgoCD or Kustomize — they filled a form.

> **Why not have the IDP deploy directly?** Because Git is the source of truth
> (Project 2). The IDP's job is to *produce the declarative config*; ArgoCD reconciles
> it. Keeping that boundary is what makes the whole system auditable and reversible.
