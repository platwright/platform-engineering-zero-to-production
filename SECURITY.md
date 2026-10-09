# Security Policy

This repository is an educational course. It contains prose, example
configuration, scripts, and labs that you run in **your own** cloud accounts and
clusters. "Security" here has two sides: keeping *this repository* free of
dangerous content, and helping *you* stay safe while doing the labs.

## Reporting a vulnerability

Please report security issues **privately** — do not open a public issue for
anything sensitive.

Preferred channel:

- Use GitHub's **[Report a vulnerability](../../security/advisories/new)**
  (Security Advisories) to open a private report.

Alternatively, email `security@example.com` *(replace with a monitored
contact before launch)*.

When reporting, please include:

- A description of the issue and where it lives (file path, module, or URL).
- Steps to reproduce or demonstrate impact.
- Any suggested remediation.

We aim to acknowledge reports within **5 business days** and to agree on a
disclosure timeline with you. Please give us reasonable time to fix an issue
before disclosing it publicly.

### What's in scope

- **Secrets accidentally committed** to this repository (tokens, keys,
  credentials) — report immediately.
- **Insecure examples** that could cause real harm if a learner follows them
  (for example, a lab that disables authentication on an internet-exposed
  service without a prominent warning).
- **Vulnerable dependencies** in sample code or tooling shipped in this repo.
- **Malicious or compromised content** (links, scripts, actions pinned to
  unsafe references).

### What's out of scope

- Vulnerabilities in the upstream tools the course teaches (Kubernetes, ArgoCD,
  Terraform, Backstage, etc.). Report those to the respective projects.
- Issues in your own cloud environment caused by running the labs.
- Theoretical issues with no demonstrable impact on this repository.

## Supported versions

This is a living course. Only the latest `main` branch is maintained and
"supported." Fixes land on `main`; there are no back-ported release branches.

## Secret hygiene (read this before any lab)

Several modules have you create cloud credentials, API keys, and Kubernetes
secrets. Treat them as if they were production secrets, because the habits you
build here are the habits you'll carry to production.

- **Never commit secrets.** This repo's [`.gitignore`](./.gitignore) excludes
  common secret files (`*.tfvars`, `*.pem`, `kubeconfig`, `credentials*.json`,
  `.env`, …), but `.gitignore` is a safety net, not a guarantee. Think before you
  `git add`.
- **Use example files.** Commit `something.example.tfvars` / `.env.example` with
  placeholder values; keep the real file untracked.
- **Prefer short-lived credentials.** Where the course offers it, use workload
  identity / OIDC keyless auth instead of long-lived service-account keys.
- **Scope credentials minimally.** Grant only the permissions a lab needs, and
  delete them when you're done.
- **Set a budget.** Cloud labs cost money. Configure billing alerts (see
  [`00-orientation/cloud-account-setup.md`](./00-orientation/cloud-account-setup.md))
  and tear resources down with the provided cleanup steps.
- **If you leak a secret:** revoke/rotate it *first*, then scrub history. Removing
  a secret in a later commit does **not** remove it from Git history — rotate the
  credential and, if needed, rewrite history (`git filter-repo`) or consider the
  secret permanently compromised.

If you believe a secret was committed to *this* repository, report it through the
private channel above so we can rotate and purge it quickly.
