# `diagrams/`

Source and exported diagrams used throughout the course. A diagram must earn its
place — include one only when it explains something that is genuinely hard to
express in prose.

| Folder | Scope |
|--------|-------|
| [`architecture/`](./architecture/) | Platform and system architecture (IDP planes, GitOps flow, control/data plane). |
| [`network/`](./network/) | Networking diagrams (pod-to-pod, services/DNS, Cilium/eBPF, Gateway API). |
| [`platform/`](./platform/) | Platform concepts (maturity model, developer journey, team topologies). |

## Conventions

- Prefer **diagram-as-code** so diagrams are reviewable and diffable: Mermaid in
  Markdown, or source files (e.g. `.drawio`, `.excalidraw`, PlantUML) committed
  next to any exported `.png`/`.svg`.
- Keep exports lightweight (`.svg` preferred; `.png` for raster).
- Name files after what they explain: `idp-five-planes.svg`, not `diagram1.svg`.

Many lessons embed simple ASCII or Mermaid diagrams inline; this folder is for the
larger, reusable ones.

### Required diagrams (built as their modules land)

Platform overview · IDP five planes · Container vs VM · OCI image structure ·
Kubernetes architecture · Kubernetes networking · RBAC model · Terraform lifecycle ·
GitOps model · ArgoCD promotion flow · Multi-cluster hub-and-spoke · Observability
data flow · SLO burn rate · Kubernetes security layers · Supply-chain pipeline ·
Secret management flow · Cilium eBPF path · Gateway API roles · IDP developer
journey · Platform maturity model. See the [ROADMAP](../ROADMAP.md).

Use the links below when a lesson needs the reusable architectural picture behind
its prose:

- [Architecture diagrams](./architecture/)
- [Network diagrams](./network/)
- [Platform diagrams](./platform/)

The repo-wide references are also maintained in the parent [README.md](../README.md).
