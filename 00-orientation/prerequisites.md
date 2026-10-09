# Prerequisites

This course assumes a competent engineer who is **new to platform engineering**.
You do **not** need any Kubernetes, Terraform, or platform experience — you'll
build all of that here. You do need some fundamentals so the course can focus on
platform engineering rather than teaching the basics of the command line.

Use the self-checks below. If you can comfortably answer most questions in a
section, you're ready. If not, the linked resources will get you there.

---

## What you need

```text
Comfortable with the Linux command line
Basic Git and GitHub
Basic Python or another scripting language
Basic cloud concepts
A machine that can run local Kubernetes
A willingness to read docs and debug
```

## What you do NOT need

- Prior Kubernetes, Docker, Terraform, or ArgoCD experience.
- A paid course, a bootcamp, or a certification.
- A powerful cloud account — labs are designed to stay within free tiers and
  small budgets, and most early labs run entirely locally.

---

## Self-check

### 1. Linux command line

You can read and write basic shell, move around a filesystem, and inspect
processes and files.

**Can you…**

- [ ] Navigate and manipulate files: `cd`, `ls`, `cp`, `mv`, `rm`, `mkdir`?
- [ ] View and search files: `cat`, `less`, `grep`, `tail -f`?
- [ ] Use pipes and redirection: `|`, `>`, `>>`, `2>&1`?
- [ ] Manage permissions: `chmod`, `chown`, and read `rwx` bits?
- [ ] Inspect the system: `ps`, `top`/`htop`, `df`, `kill`?
- [ ] Set and use environment variables: `export FOO=bar`, `echo $FOO`?
- [ ] Edit a file over SSH with `vim` or `nano`?

**Fill gaps:** [The Missing Semester of Your CS Education](https://missing.csail.mit.edu/)
· [Linux Journey](https://linuxjourney.com/)

### 2. Git and GitHub

You can work with a repository and collaborate through pull requests.

**Can you…**

- [ ] Clone, stage, commit, and push: `git clone`, `add`, `commit`, `push`?
- [ ] Work with branches: `git branch`, `checkout -b`, `merge`?
- [ ] Open a pull request on GitHub and respond to review?
- [ ] Read a diff and resolve a simple merge conflict?
- [ ] Explain what a commit and a branch actually are?

**Fill gaps:** [Pro Git (free book)](https://git-scm.com/book/en/v2)
· [GitHub Skills](https://skills.github.com/)

### 3. Scripting (Python or similar)

You can write small programs to automate tasks. Python is used in the course for
automation and tooling, but any scripting background transfers.

**Can you…**

- [ ] Write a script with variables, conditionals, loops, and functions?
- [ ] Read and write files and parse JSON/YAML?
- [ ] Call a REST API and handle the response?
- [ ] Run a script and interpret an error/traceback?
- [ ] Manage dependencies (e.g. a Python virtual environment)?

**Fill gaps:** [Automate the Boring Stuff with Python](https://automatetheboringstuff.com/)
· [Python official tutorial](https://docs.python.org/3/tutorial/)

> A little **Go** shows up later (operators and the platform CLI). You don't need
> it now — the relevant modules introduce what you need.

### 4. Cloud concepts

You understand the basic cloud building blocks. The course uses **Google Cloud
(GKE)** as its primary platform, but the concepts are provider-agnostic.

**Can you explain…**

- [ ] The difference between a VM, a container, and a managed service?
- [ ] What a region and an availability zone are?
- [ ] What IAM is (identities, roles, permissions) at a high level?
- [ ] What object storage (S3 / GCS) is, versus a block disk?
- [ ] Roughly how cloud billing works (you pay for what you provision)?

**Fill gaps:** [Google Cloud — Getting started](https://cloud.google.com/docs/get-started)
· the cloud concepts are reinforced in [Infrastructure as Code](../05-infrastructure-as-code/).

### 5. Networking basics (helpful, not required)

A little networking makes Kubernetes networking far easier.

**Do you know…**

- [ ] What an IP address, port, and DNS name are?
- [ ] The difference between TCP and UDP at a high level?
- [ ] What HTTP request/response and status codes look like?
- [ ] What a load balancer does?

**Fill gaps:** don't worry if this is shaky — [Kubernetes
Networking](../14-kubernetes-networking/) builds it up from fundamentals.

---

## Hardware & accounts

**Local machine** (for Docker and local Kubernetes with kind/k3d):

| Resource | Minimum | Comfortable |
|----------|---------|-------------|
| CPU | 2 cores | 4+ cores |
| RAM | 8 GB | 16+ GB |
| Disk | 20 GB free | 50+ GB free |
| OS | Linux, macOS, or Windows 10/11 with **WSL2** | — |

> **Windows users:** install [WSL2](https://learn.microsoft.com/windows/wsl/install)
> and run the labs inside a Linux distribution. The course assumes a Linux
> environment; WSL2 gives you one. A Windows-native prerequisite check
> ([`check-prerequisites.ps1`](../scripts/check-prerequisites.ps1)) is provided,
> but the labs themselves target Linux.

**Accounts you'll need:**

- A **GitHub account** (free).
- A **Google Cloud account** with billing enabled — set up *safely*, with budget
  alerts, in [`cloud-account-setup.md`](./cloud-account-setup.md). New accounts
  include free credit, and the labs are designed to be inexpensive. You can defer
  this until the Infrastructure as Code phase.

---

## Ready?

Run the prerequisite checker to see which tools you still need:

```bash
./scripts/check-prerequisites.sh      # Linux / macOS / WSL2
./scripts/check-prerequisites.ps1     # Windows PowerShell
```

Then set up your environment: [`environment-setup.md`](./environment-setup.md).
