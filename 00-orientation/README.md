# 00 · Orientation — How to Use This Course

> **Start here.** This module explains how the course is organized, how to work
> through it, what you need, and how to set up your environment. Spend 30–45
> minutes here before diving into the curriculum — it will save you hours later.

## What this module covers

- [How the repository is organized](#how-the-repository-is-organized)
- [How each module is structured](#how-each-module-is-structured)
- [The recommended learning sequence](#the-recommended-learning-sequence)
- [How labs work and how you're "graded"](#how-labs-work-and-how-youre-graded)
- [Estimated effort](#estimated-effort)
- [Secret and API-key hygiene](#secret-and-api-key-hygiene)
- [Tracking your progress](#tracking-your-progress)
- [Getting help](#getting-help)

The rest of this module's files go deeper:

| File | Read it to… |
|------|-------------|
| [`learning-path.md`](./learning-path.md) | Pick a track (Platform Engineer / DX Engineer / Architect) and a pace. |
| [`prerequisites.md`](./prerequisites.md) | Check you're ready, and fill any gaps. |
| [`environment-setup.md`](./environment-setup.md) | Install Docker, kubectl, kind, Terraform, Go, and friends. |
| [`cloud-account-setup.md`](./cloud-account-setup.md) | Create a GCP project safely, with billing alerts. |
| [`glossary.md`](./glossary.md) | Look up any unfamiliar term. |
| [`learning-progress.md`](./learning-progress.md) | Copy this and track what you've completed. |

---

## How the repository is organized

The course is a sequence of numbered top-level folders. Numbers define the
recommended order:

```text
00-orientation/            ← you are here
01-platform-foundations/   ← concepts: what platform engineering is
02-containerization/       ← build-up of technical skills…
03-kubernetes-fundamentals/
04-platform-project-01/    ← a project consolidates the prior phases
05-infrastructure-as-code/
…                          ← and so on, through to
21-capstone-projects/      ← portfolio-grade builds
22-interview-preparation/  ← reference
23-cheat-sheets/           ← reference
```

Three kinds of top-level folder:

- **Phases** (e.g. `02`, `03`, `05`) teach a body of knowledge as a set of
  modules.
- **Projects** (e.g. `04`, `09`, `12`, `16`) consolidate several phases into one
  buildable system. This is where knowledge becomes skill.
- **Reference** (`22`, `23`) supports the whole journey.

Supporting directories you'll use along the way:

| Directory | Purpose |
|-----------|---------|
| [`shared/`](../shared/) | Reusable Terraform modules, Helm charts, GitHub Actions, and authoring templates. |
| [`scripts/`](../scripts/) | Helper scripts — including the prerequisite checker. |
| [`diagrams/`](../diagrams/) | Architecture, network, and platform diagrams. |
| [`datasets/`](../datasets/) · [`notebooks/`](../notebooks/) | Data and notebooks for data-driven exercises. |

The full map, with status for every module, is in the
[ROADMAP](../ROADMAP.md).

---

## How each module is structured

Every teaching module follows the **same nine-part arc**. This is deliberate: the
course's core belief is that engineers who learn tools without understanding the
problem build fragile platforms.

```text
1. Concept                      — the idea, explained from first principles
2. Why it matters               — where it shows up in real platform work
3. Mental model                 — a durable way to think about it
4. Minimal implementation       — build the smallest version yourself…
5. Hands-on lab                 — …then do it for real
6. Production considerations    — what changes at scale, for many teams
7. Common mistakes              — and how to avoid them
8. Assessment                   — check your understanding
9. Further reading              — go deeper
```

> The pattern in one line: **Understand the problem first. Build the smallest
> solution yourself. Then use the production tool. Know why every component
> exists.**

A module folder looks like this:

```text
NN-module-name/
├── README.md     ← the lesson (the nine parts above)
└── lab/
    └── README.md ← the hands-on lab, plus any worksheets/starter files
```

---

## The recommended learning sequence

If you're new to platform engineering, **just go in order** — `00 → 01 → 02 → …`.
The numbering is the path.

If you have relevant experience, or a specific role in mind, choose a **track** or
the **12-week fast track** in [`learning-path.md`](./learning-path.md). All tracks
share the same core; they differ in emphasis and optional depth.

A simple loop for each module:

1. Read the lesson (`README.md`).
2. Do the lab (`lab/README.md`) — don't skip it; the lab is where it sticks.
3. Answer the assessment questions honestly.
4. Note the production considerations.
5. Tick the boxes in your progress tracker and move on.

---

## How labs work and how you're "graded"

This is a self-paced course, so **grading is self-assessment** — but it's not
hand-wavy. Each lab produces a concrete **deliverable** and tells you what success
looks like.

Labs come in a few flavors:

| Type | You… | Example |
|------|------|---------|
| **Discovery** | investigate and document | Interview engineers about deployment pain (Module 01.1). |
| **Design** | produce an artifact | Write a one-page Platform Product Brief (Module 01.2). |
| **Build** | provision/deploy something that works | Stand up a GKE foundation (Project 1). |
| **Debug** | diagnose and fix broken state | Fix five broken Kubernetes manifests (Kubernetes module). |

Hold yourself to this bar — it's the course's definition of "done" for a lab:

- [ ] The deliverable exists and is complete (not a stub).
- [ ] You can explain *why*, not just reproduce the *how*.
- [ ] For build labs: another person could reproduce it from your notes.
- [ ] For build labs: you ran the **cleanup** step and left no surprise cloud bills.

Projects and capstones have a higher bar — a full **portfolio-ready checklist**
(architecture diagram, IaC, GitOps delivery, tests, observability, SLOs, security,
cost, runbooks, DR). You'll meet it when you get there; it's in the
[ROADMAP](../ROADMAP.md#target-outcomes).

---

## Estimated effort

Treat these as rough guides for a motivated engineer. Go slower if a topic is new;
faster if you've seen it before. Depth beats speed.

| Phase | Modules | Rough effort |
|-------|---------|--------------|
| 00 · Orientation | — | 1–2 hrs (plus setup) |
| 01 · Platform Foundations | 5 | 6–9 hrs |
| 02 · Containerization | 7 | 10–14 hrs |
| 03 · Kubernetes Fundamentals | 9 | 18–25 hrs |
| 04 · Project 1 | — | 8–12 hrs |
| 05 · Infrastructure as Code | 7 | 14–20 hrs |
| 06 · CI/CD | 6 | 10–14 hrs |
| 07 · Package Management | 5 | 8–12 hrs |
| 08 · GitOps | 6 | 10–14 hrs |
| 09 · Project 2 | — | 8–12 hrs |
| 10 · Kubernetes Advanced | 5 | 12–18 hrs |
| 11 · Observability | 8 | 14–20 hrs |
| 12 · Project 3 | — | 8–12 hrs |
| 13 · Security & Policy | 8 | 14–20 hrs |
| 14 · Networking | 6 | 10–16 hrs |
| 15 · Developer Experience & IDP | 8 | 16–24 hrs |
| 16 · Project 4 | — | 12–20 hrs |
| 17 · Platform SRE | 6 | 10–14 hrs |
| 18 · FinOps | 5 | 8–12 hrs |
| 19 · Multi-Cluster & Multi-Cloud | 4 | 8–12 hrs |
| 20 · Advanced Topics | 4 | 6–10 hrs |
| 21 · Capstones | 4 | 20–60+ hrs each |

Full-time, the core is roughly a **12-week** effort (see the fast track). Part-time
at ~6 hours/week, budget **6–9 months**. There is no prize for rushing.

---

## Secret and API-key hygiene

Several modules have you create real cloud credentials and secrets. **Build good
habits now** — they're the habits you'll carry to production.

The essentials (full detail in [SECURITY.md](../SECURITY.md)):

- **Never commit secrets.** The repo's [`.gitignore`](../.gitignore) excludes common
  secret files, but that's a safety net, not a guarantee. Think before `git add`.
- **Commit example files only** (`*.example.tfvars`, `.env.example`) with
  placeholder values.
- **Prefer short-lived, keyless credentials** (OIDC / workload identity) over
  long-lived service-account keys wherever the course offers it.
- **Scope credentials minimally** and delete them when a lab is done.
- **Set a budget** on your cloud account and configure billing alerts — see
  [`cloud-account-setup.md`](./cloud-account-setup.md).
- **If you leak a secret, rotate it first**, then clean history. A secret removed
  in a later commit still lives in Git history — treat it as compromised.

---

## Tracking your progress

Copy the tracker to a personal file (kept out of version control) and check things
off as you go:

```bash
cp 00-orientation/learning-progress.md my-learning-progress.md
```

Each module is "done" when you can tick:

```text
[ ] Theory completed
[ ] Lab completed
[ ] Architecture reviewed
[ ] Assessment completed
[ ] Production considerations documented
```

---

## Getting help

- **Something wrong or unclear?** Open an [issue](../../issues) using the content
  or lab template.
- **Want to discuss or ask a question?** Use
  [Discussions](../../discussions).
- **Want to improve the course?** See [CONTRIBUTING.md](../CONTRIBUTING.md).

---

### Next steps

1. Confirm you're ready: [`prerequisites.md`](./prerequisites.md)
2. Set up your tools: [`environment-setup.md`](./environment-setup.md)
3. Set up cloud (safely): [`cloud-account-setup.md`](./cloud-account-setup.md)
4. Choose your path: [`learning-path.md`](./learning-path.md)
5. Begin: [**01 · Platform Foundations →**](../01-platform-foundations/)
