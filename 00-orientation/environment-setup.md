# Environment Setup

This page gets your local toolbelt ready. You don't need everything on day one —
the table shows when each tool first appears, so you can install as you go. The
**core** tools are enough to start.

> **Windows:** do the labs inside **WSL2** (a real Linux environment). Install
> [WSL2](https://learn.microsoft.com/windows/wsl/install), then follow the
> **Linux** instructions below from inside your WSL distribution. Install Docker
> Desktop on Windows with the WSL2 backend enabled.

## Check what you already have

```bash
./scripts/check-prerequisites.sh      # Linux / macOS / WSL2
./scripts/check-prerequisites.ps1     # Windows PowerShell
```

It prints versions, flags missing **core** tools, and never installs anything.

---

## The toolbelt

| Tool | Purpose | First introduced | Tier |
|------|---------|------------------|------|
| **git** | Version control | 00 · Orientation | core |
| **Docker** / BuildKit | Build & run containers | 02 · Containerization | core |
| **kubectl** | Operate Kubernetes | 03 · Kubernetes | core |
| **kind** (or **k3d**) | Local Kubernetes clusters | 03 · Kubernetes | core |
| **Terraform** | Infrastructure as code | 05 · IaC | core |
| **Go** | Operators & platform CLIs | 10 · K8s Advanced | core |
| **Python 3** | Automation & scripting | throughout | core |
| **Helm** | K8s package manager | 07 · Package Mgmt | recommended |
| **Kustomize** | K8s config overlays | 07 · Package Mgmt | recommended |
| **gcloud** | Google Cloud CLI | 05 · IaC / Project 1 | recommended |
| **jq** / **yq** | JSON/YAML processing | throughout | recommended |
| **Trivy** | Image vulnerability scanning | 02, 13 | recommended |
| **Cosign** | Image signing (Sigstore) | 06, 13 | recommended |
| **ArgoCD CLI** | GitOps | 08 · GitOps | recommended |
| **Node.js** | Backstage & tooling | 15 · IDP | later |

---

## Fastest path by OS

### macOS — Homebrew

Install [Homebrew](https://brew.sh/), then:

```bash
# Core
brew install git kubectl kind terraform go python@3.12
brew install --cask docker        # Docker Desktop

# Recommended (install now or later)
brew install helm kustomize jq yq trivy cosign argocd
brew install --cask google-cloud-sdk
```

Start Docker Desktop once after installing so the daemon is running.

### Linux (Debian/Ubuntu, incl. WSL2)

Install what's in the distro repos first:

```bash
sudo apt-get update
sudo apt-get install -y git python3 python3-pip jq
```

Then install the rest from their official sources (versions and URLs change, so
these link to the canonical instructions):

- **Docker Engine** — <https://docs.docker.com/engine/install/> (and the
  [post-install steps](https://docs.docker.com/engine/install/linux-postinstall/)
  so you can run `docker` without `sudo`). On WSL2, prefer **Docker Desktop** with
  the WSL2 backend instead.
- **kubectl** — <https://kubernetes.io/docs/tasks/tools/#kubectl>
- **kind** — <https://kind.sigs.k8s.io/docs/user/quick-start/#installing>
- **Terraform** — <https://developer.hashicorp.com/terraform/install>
- **Go** — <https://go.dev/doc/install>
- **Helm** — <https://helm.sh/docs/intro/install/>
- **Kustomize** — <https://kubectl.docs.kubernetes.io/installation/kustomize/>
- **gcloud** — <https://cloud.google.com/sdk/docs/install>
- **Trivy** — <https://trivy.dev/latest/getting-started/installation/>
- **Cosign** — <https://docs.sigstore.dev/cosign/system_config/installation/>
- **ArgoCD CLI** — <https://argo-cd.readthedocs.io/en/stable/cli_installation/>

<details>
<summary>Example: install kind and kubectl on Linux (amd64)</summary>

```bash
# kubectl (latest stable)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
rm kind
```

</details>

### Windows (native tooling)

Use [WSL2](https://learn.microsoft.com/windows/wsl/install) for the labs. For
Windows-native CLIs (optional), use [winget](https://learn.microsoft.com/windows/package-manager/):

```powershell
winget install Git.Git
winget install Kubernetes.kubectl
winget install Kubernetes.kind
winget install Hashicorp.Terraform
winget install GoLang.Go
winget install Python.Python.3.12
winget install Docker.DockerDesktop
```

> Even with these installed on Windows, **run the labs inside WSL2**. The course's
> shell scripts, container workflows, and Kubernetes tooling assume Linux.

---

## A good version-manager option (optional)

If you like managing many CLI versions cleanly, [`asdf`](https://asdf-vm.com/) or
[`mise`](https://mise.jdx.dev/) can install pinned versions of kubectl, Terraform,
Go, Helm, and more from a single config. This is handy once you're juggling
project-specific versions.

---

## Local Kubernetes: kind vs k3d

Early Kubernetes labs run **locally** (no cloud cost) on a throwaway cluster.
Either tool works:

- **[kind](https://kind.sigs.k8s.io/)** — Kubernetes IN Docker. The course's
  default; examples use it.
- **[k3d](https://k3d.io/)** — lightweight k3s in Docker; very fast, low memory.

Smoke-test your local cluster now if you've installed Docker + kind:

```bash
kind create cluster --name smoke-test
kubectl get nodes
kind delete cluster --name smoke-test   # cleanup
```

---

## Recommended editor

[Visual Studio Code](https://code.visualstudio.com/) with these extensions covers
the whole course well:

```text
ms-vscode-remote.remote-wsl        (Windows: edit inside WSL2)
ms-azuretools.vscode-docker
ms-kubernetes-tools.vscode-kubernetes-tools
hashicorp.terraform
golang.go
ms-python.python
redhat.vscode-yaml
```

Any editor is fine — use what you're productive in.

---

## Verify

```bash
./scripts/check-prerequisites.sh
```

All **core** tools green? You're ready. Next, set up cloud safely in
[`cloud-account-setup.md`](./cloud-account-setup.md), or jump straight into
[**01 · Platform Foundations →**](../01-platform-foundations/) (it needs no cloud).
