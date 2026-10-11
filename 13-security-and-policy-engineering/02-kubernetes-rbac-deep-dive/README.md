# Module 13.2 — Kubernetes RBAC Deep Dive

> Module 03.6 taught you to *write* a Role and bind it. Production asks a harder question: across
> hundreds of bindings, **who can actually do what — and how do you prove it?** This module turns RBAC
> into something you **audit, compose, and time-box** — so least privilege becomes a guardrail the
> platform maintains, not a rule each team has to remember.

**Estimated effort:** ~2 hours (theory + lab)
**You'll need:** [Module 03.6 · RBAC](../../03-kubernetes-fundamentals/06-rbac/) (Roles,
bindings, `auth can-i`), plus a working `kubectl` + [kind](https://kind.sigs.k8s.io/).

## Learning objectives

By the end of this module you will be able to:

- Distinguish **ServiceAccounts** (identities you manage) from **Users/Groups** (vouched for by an
  external authenticator), and explain where each comes from.
- Reveal any subject's **effective permissions** with impersonation and
  `kubectl auth can-i --list --as=…`.
- Compose capability with **aggregated ClusterRoles** instead of copy-pasting rules.
- **Audit** a cluster for over-broad grants — wildcards, `cluster-admin` holders, and cluster-wide
  ServiceAccounts — and map findings to OWASP **K03**.
- Reason about **just-in-time access**, **cross-namespace** grants, **CI/CD identity**, and
  **API server audit logging**.

---

## 1. Concept

### Subjects revisited: the identities you manage

RBAC has three subject kinds, and the distinction matters more than Module 03.6 let on:

- **Users** and **Groups** are *strings an authenticator vouches for*. Kubernetes has no user table; it
  trusts whatever proves identity at the API server's door — a client certificate's `CN`/`O`, or in
  production an **OIDC** provider returning username and group claims from your SSO. You never "create" a
  User; you configure the authenticator and *bind* the names it emits.
- **ServiceAccounts** are real, namespaced objects — machine identities for workloads and automation,
  which you create, rotate, and audit.

So you **bind groups for humans** (access follows SSO; a leaver loses cluster access automatically) and
**manage ServiceAccounts for machines** — the identities you own outright, where most least-privilege
work lives.

### Reading effective permissions: ask the authorizer

The trap at scale: **a subject's real permissions are the union of every binding that names it** —
directly, through a Group, or through an *aggregated* ClusterRole. No single object shows the total, so
reading one Role tells you almost nothing. Instead, **ask the authorizer**: impersonation (`--as`,
`--as-group`) runs the exact check Kubernetes would, with no context switch and no stolen credentials:

```bash
# Everything a CI ServiceAccount can do, as the API server sees it:
kubectl auth can-i --list \
  --as=system:serviceaccount:team-apps:cicd-deployer -n team-apps
```

`--list` enumerates the whole effective rule set; a plain `kubectl auth can-i <verb> <resource> --as=…`
answers one yes/no. This is how you *verify* a grant instead of hoping — the most important RBAC skill
this module adds.

### Aggregated ClusterRoles: compose capability, don't copy it

Listing every rule in one object rots: each new capability means editing a giant role and re-reviewing
all of it. **Aggregation** fixes this — a ClusterRole with an `aggregationRule` owns *no rules of its
own*; the control plane unions in every ClusterRole whose labels match:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-viewer
aggregationRule:
  clusterRoleSelectors:
    - matchLabels:
        rbac.example.com/aggregate-to-viewer: "true"
rules: []   # intentionally empty — the controller aggregates matching roles
```

Add capability by adding a small, labeled role — no edit to `platform-viewer`, no re-review of the whole:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: view-pods
  labels:
    rbac.example.com/aggregate-to-viewer: "true"
rules:
  - apiGroups: [""]
    resources: ["pods", "services"]
    verbs: ["get", "list", "watch"]
```

Label a role → it joins in seconds; remove the label → it leaves. Kubernetes builds its own
`view`/`edit`/`admin` roles this way — the pattern a platform uses to publish a growing **capability
catalog**: review each small role once, reuse it everywhere.

### Auditing RBAC: hunting the over-broad grant

RBAC *drifts permissive* — every "just one more permission" is a ratchet that turns one way. Three
findings cause most real incidents, and together they are OWASP **K03 — overly permissive RBAC**:

- **Wildcards** — `verbs`, `resources`, or `apiGroups: ["*"]`; a wildcard silently absorbs every resource
  type added later. Enumerate instead.
- **`cluster-admin` holders** — anything bound to it owns the cluster; the list should be tiny and known.
- **Cluster-wide ServiceAccounts** — a machine identity bound by a *ClusterRoleBinding* acts in every
  namespace, so a leaked token is a cluster-wide incident.

Find all three with `kubectl -o json | jq`. Tools go further: **`kubectl-who-can`** (a krew plugin
answering "who can `<verb> <resource>`?"), **KubiScan** (risky roles and tokens), and **rbac-tool**
(visualize, lint, generate least-privilege roles). The lab builds the `jq` audit by hand first — a tool
you can't reproduce with `jq` is one you can't trust.

### Cross-namespace access: narrow by default

A workload in namespace A legitimately needs a ConfigMap in namespace B (shared config, a platform
controller, a cross-team contract). Two ways, and the difference *is* the lesson:

- **ClusterRole + RoleBinding in the target namespace** — define the permission set once as a ClusterRole
  (a *reusable template*, not a cluster-wide grant), then bind it with a RoleBinding **in namespace B**.
  The subject gets those rights **only in B** — the narrow, correct answer.
- **ClusterRoleBinding** — grants the role in **every** namespace. Use it only for a genuinely
  cluster-wide need (a monitoring reader), never for a one-namespace problem.

Rule of thumb: *a ClusterRole is a reusable noun; a ClusterRoleBinding is a cluster-wide verb.*

### Just-in-time access: no standing privilege

The most dangerous permission is the one that sits unused until an attacker finds it. **Standing
privilege** — permanent `cluster-admin`, an always-live break-glass account — is blast radius waiting to
happen. **Just-in-time (JIT)** access grants elevation only when needed, scoped and **time-boxed**, then
revokes it automatically:

- **Short-lived bindings** — create a RoleBinding on approval, delete it on a timer (a controller that
  reaps bindings older than *N* minutes).
- **Access-request tooling** — a workflow that mints the binding after approval and records who/why.
- **Break-glass** — a sealed, heavily-audited emergency path that alerts on use.

The goal is **zero standing privileges**: nothing carries power it isn't using right now — a pillar of
zero trust, built out in [Module 13.8](../08-zero-trust-for-platforms/).

### Watching the authorizer: API server audit logging

RBAC decides *whether* a request is allowed; **audit logging** records *that it happened*. Point the API
server at an `--audit-policy-file`, which picks a level per rule:

- **`None`** — don't log (health checks, chatty watches).
- **`Metadata`** — who, verb, resource, allowed/denied — no bodies; the sane default.
- **`Request`** — metadata **plus the request body**.
- **`RequestResponse`** — request and response bodies; reserve for sensitive resources (RBAC objects,
  Secrets).

Then **ship the logs** off the node into Phase 11's pipeline — one nobody queries is just disk usage.
This is how a `cluster-admin` grant at 03:00 becomes an alert, not an archaeology project.

---

## 2. Why it matters for platform engineering

- **You own the machine identities.** Every pipeline, operator, and controller runs as a ServiceAccount
  *you* create — and over-privileged automation is the top real-world RBAC risk.
- **Least privilege must be provable.** `kubectl auth can-i --list --as=…` turns a claim into evidence on
  demand.
- **Composition scales; copy-paste doesn't.** Aggregated ClusterRoles publish a catalog teams opt into,
  not monolith roles re-reviewed on every change.
- **Audit is a product feature.** "Who can read Secrets in prod?" is one command against a structural RBAC
  model, a spreadsheet-and-a-prayer against a bolt-on one.
- **Blast-radius math is the point.** Tight, namespace-scoped, time-boxed grants decide whether a leaked
  token means "one namespace" or "whole cluster" — and assume-breach says it *will* leak
  ([Module 13.1](../01-security-principles/)).

---

## 3. Mental model

**First: effective permissions are a union you must query, not read.**

```text
  Effective permissions = UNION of every binding that names the subject
  ─────────────────────────────────────────────────────────────────────
  ServiceAccount: team-apps/cicd-deployer
       │
       ├─ RoleBinding (ns team-apps) ─► Role: deploy-manager
       │        get,list,create,update,patch   deployments, services
       │
       ├─ RoleBinding (ns team-apps) ─► ClusterRole: configmap-reader
       │        get,list,watch   configmaps
       │
       └─ Group system:serviceaccounts ─► any binding to that group
                inherited — easy to forget, easy to over-grant

  No single object shows the total. Ask the authorizer:
    kubectl auth can-i --list --as=system:serviceaccount:team-apps:cicd-deployer
```

**Second: every grant is a blast radius** — the same capability costs different amounts by *scope*:

```text
  One leaked ServiceAccount token
  ──────────────────────────────────────────────────────────────
  Narrow (RoleBinding, 1 ns)          Broad (ClusterRoleBinding, *)
     token → team-apps only              token → every namespace
     ├ manage its deployments            ├ read ALL secrets (creds, tokens)
     └ cannot read secrets               ├ create clusterrolebindings
        cannot leave the namespace       └ self-escalate to cluster-admin
     ⇒ incident = one namespace         ⇒ incident = whole cluster
```

Design every grant with the Module 13.1 question: *if this subject is compromised, what can it reach, and
do there?* All RBAC work is shrinking both answers.

---

## 4. Minimal implementation

The smallest honest RBAC audit needs no new tools — just the authorizer and `jq`. Start with the question
that matters most: **what can this subject actually do?**

```bash
# Reveal a subject's full effective permissions (no context switch, no creds):
kubectl auth can-i --list \
  --as=system:serviceaccount:kube-system:namespace-controller
```

A short list is health; `*  *` (every verb on every resource) is a finding. Now sweep the whole cluster
for the roles that grant that wildcard:

```bash
# The smallest wildcard-hunter: every ClusterRole granting * verbs, resources, or apiGroups.
kubectl get clusterroles -o json \
  | jq -r '.items[]
      | select(.rules[]? | (((.verbs // []) | index("*")) != null)
            or (((.resources // []) | index("*")) != null)
            or (((.apiGroups // []) | index("*")) != null))
      | .metadata.name' | sort -u
```

That one pipe names every ClusterRole holding the keys to expanding permissions. Cross-reference the hits
against who they're *bound* to (the lab's `rbac-audit.sh` does this) and you've found OWASP **K03** in
minutes, without installing anything. Reach for `kubectl-who-can` or KubiScan to go faster.

---

## 5. Hands-on lab

You'll stand up a kind cluster, audit it for wildcard roles, `cluster-admin` holders, and cluster-wide
ServiceAccounts with a `jq` script, answer "who can do X?" with `who-can` (or a pure-`kubectl` fallback),
grow an **aggregated ClusterRole** by adding one labeled role, and build a least-privilege **CI/CD
ServiceAccount** you prove — granted *and* denied — with `kubectl auth can-i --as=…`.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Bind groups, not users.** Wire the API server to OIDC and bind *groups* from SSO; joiners and leavers
  are handled by the IdP, not hand-edited certs.
- **Continuously audit.** Run the wildcard / `cluster-admin` / cluster-wide-SA sweep in CI and on a
  schedule — RBAC drifts permissive, and that drift *is* the finding.
- **Make capabilities a catalog.** Publish aggregated ClusterRoles (`app-team-admin`, `platform-viewer`)
  teams opt into, instead of approving bespoke roles per request.
- **No standing privilege for humans.** Default human access to read-only; elevate through time-boxed JIT
  with an audit trail, and keep break-glass sealed and alerting.
- **Turn on audit logging from day one.** `Metadata` for reads, `RequestResponse` for RBAC/Secrets, shipped
  to Phase 11 — retro-fitting it after an incident is too late.
- **CI identity is least-privilege by construction.** Per-namespace ServiceAccount, short-lived tokens,
  never `cluster-admin` — the pattern Project 1 ([`04-platform-project-01`](../../04-platform-project-01/))
  and Project 2 ([`09-platform-project-02`](../../09-platform-project-02/)) wire into delivery.

---

## 7. Common mistakes

- **Reading one Role and calling it the permission set** — effective access is the union of *all* bindings
  (direct, group, aggregated). *Fix:* verify with `kubectl auth can-i --list --as=<subject>`.
- **Wildcards for convenience** — `["*"]` "to make it work" grants far more than intended and grows as new
  APIs ship. *Fix:* enumerate exact verbs and resources; audit for `*`.
- **`cluster-admin` for a one-namespace job** — the fastest way to unblock CI, and to lose the cluster.
  *Fix:* a namespace-scoped Role + RoleBinding, or a ClusterRole bound by a RoleBinding in the one target
  namespace.
- **Standing privilege "just in case"** — permanent elevation nobody uses is pure blast radius. *Fix:*
  time-boxed JIT bindings and zero standing privileges (Module 13.8).
- **Hand-maintained monolith roles** — one giant shared role re-reviews everything on each change and tempts
  over-granting. *Fix:* aggregated ClusterRoles composed from small, labeled roles.
- **RBAC without audit logging** — you see *who can* act but have no record of who *did*. *Fix:* enable API
  server audit logging and ship it to observability.

---

## 8. Assessment

**Knowledge checks**

1. Where do Users and Groups come from in Kubernetes, and why are ServiceAccounts the subject type a
   platform team actually manages?
2. How do you reveal the *complete* effective permissions of a subject, and why can't you read them off any
   single Role or binding?
3. What problem do aggregated ClusterRoles solve, and how does
   `aggregationRule.clusterRoleSelectors.matchLabels` grow the aggregate?
4. To let a workload in namespace `a` read ConfigMaps in namespace `b`, which objects do you create — and
   why is a ClusterRoleBinding the wrong tool?
5. Name the API server audit levels and say what each records. Which would you use for Secrets?

**Concept exercise**

> Explain to a new platform engineer how to discover *every* action a leaked machine-identity token would
> let an attacker take — **without using the words "RBAC," "impersonation," or any command or tool name.**
> Make the "permissions are a union, not a line in one file" idea land.

**Trade-off / debugging exercise**

> A workload's identity, checked with `auth can-i --list`, shows `*  *` — full access. The owning team swears
> they only bound it to a small, read-only Role in their namespace. Give at least two ways it could still
> have `*`, how you'd locate the grant, and what structural change stops this class of problem recurring.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** They're strings an authenticator (client certs or OIDC/SSO) vouches for — Kubernetes has no user
  table, so you bind the names it emits. ServiceAccounts are real namespaced objects you create, rotate,
  and audit, so least-privilege work concentrates there.
- **Q2:** Ask the authorizer — `kubectl auth can-i --list --as=<subject>` (plus `--as-group`). Effective
  access is the union of every binding naming the subject directly, via a Group, or via aggregation; no one
  object holds the total.
- **Q3:** They compose a big role from small labeled ones: the empty-ruled role's `matchLabels` unions in
  every ClusterRole carrying the label. Add or remove capability by adding or removing a labeled role.
- **Q4:** A ClusterRole **plus a RoleBinding in namespace `b`** — the rights apply *only* in `b`. A
  ClusterRoleBinding would grant them in every namespace.
- **Q5:** `None`, `Metadata` (who/verb/resource/decision), `Request` (adds request body), `RequestResponse`
  (adds response body). Use `RequestResponse` for Secrets and RBAC objects.
- **Trade-off:** `*  *` can come from a `cluster-admin`/wildcard ClusterRole bound via a Group the SA
  belongs to (e.g. `system:serviceaccounts`), an aggregated role that pulled in a wildcard labeled role, or
  a stray ClusterRoleBinding. Find it by listing every binding that names the subject or its groups and
  checking each `roleRef` for wildcards. Structural fix: forbid wildcard/`cluster-admin` grants to
  ServiceAccounts in policy (Module 13.3), compose via labeled aggregation, and audit continuously.

</details>

---

## 9. Further reading

- Kubernetes — [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) (aggregation, default roles)
- Kubernetes — [`kubectl auth can-i`](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_auth/kubectl_auth_can-i/)
- Kubernetes — [Auditing](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)
- OWASP — [Kubernetes Top 10 (K03: Overly Permissive RBAC)](https://owasp.org/www-project-kubernetes-top-10/)
- Aqua Security — [kubectl-who-can](https://github.com/aquasecurity/kubectl-who-can)
- CyberArk — [KubiScan](https://github.com/cyberark/KubiScan)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 13.1 — Security Principles for Platform Teams](../01-security-principles/)
· _Next:_ [Module 13.3 — Policy as Code with Kyverno →](../03-policy-as-code-with-kyverno/)
