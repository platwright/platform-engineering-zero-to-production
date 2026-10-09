# Module 03.6 — RBAC

> Every request to the Kubernetes API is authenticated and then **authorized**.
> Role-Based Access Control (RBAC) is how you grant precisely the permissions a
> human, a CI pipeline, or a workload needs — and nothing more. This module teaches
> RBAC from first principles so "who can do what, where" becomes something you can
> design and prove, not guess.

**Estimated effort:** ~2 hours (theory + lab)
**You'll need:** [Module 03.1](../01-kubernetes-architecture/) and a working
`kubectl` + [kind](https://kind.sigs.k8s.io/).

## Learning objectives

By the end of this module you will be able to:

- Distinguish **authentication** from **authorization**, and name RBAC's four object
  types.
- Identify **subjects**: Users, Groups, and **ServiceAccounts**.
- Write a **Role**/**ClusterRole** (permissions) and bind it with a
  **RoleBinding**/**ClusterRoleBinding** (grant).
- Apply **least privilege** and reason about namespace-scoped vs cluster-scoped
  access.
- Prove any subject's effective permissions with **`kubectl auth can-i`**.

---

## 1. Concept

### Authn vs authz, and "deny by default"

Two gates stand between a request and the cluster:

- **Authentication (authn)** — *who are you?* Certificates, tokens, or an external
  identity provider establish identity. Kubernetes has **no** user database; it
  trusts an authenticator.
- **Authorization (authz)** — *are you allowed to do this?* RBAC answers this by
  checking the identity's granted permissions.

RBAC is **additive and default-deny**: nothing is allowed unless a rule grants it,
and there are no "deny" rules — you simply don't grant what you don't want. To know
if an action is permitted, Kubernetes asks: *does any binding give this subject a
role whose rules allow this verb on this resource (in this namespace)?*

### Subjects: who is asking

- **Users** and **Groups** — human (or external) identities. Kubernetes doesn't
  create these; they come from your authenticator (certs, OIDC). A `User` is just a
  string the authenticator vouches for.
- **ServiceAccounts** — identities **for workloads** (and automation like CI). These
  *are* Kubernetes objects, namespaced, and a Pod runs as one. This is the subject
  type you'll manage most.

Every Pod gets a ServiceAccount (the namespace's `default` if you don't specify one),
and its token is mounted into the Pod so in-cluster code can call the API as that
identity.

### Roles: what can be done

A **Role** is a list of **rules**, each combining:

- **apiGroups** — `""` (core: Pods, Services, ConfigMaps), `apps` (Deployments),
  `rbac.authorization.k8s.io`, etc.
- **resources** — `pods`, `deployments`, `secrets`, `pods/log`, …
- **verbs** — `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`.

Two scopes:

- **Role** — permissions **within a single namespace**.
- **ClusterRole** — permissions that are **cluster-wide**, *or* reusable permission
  sets that can be bound per-namespace, *or* the only way to grant access to
  **cluster-scoped** resources (nodes, namespaces, PersistentVolumes) and
  non-resource URLs.

A Role/ClusterRole on its own grants nothing — it's just a named set of permissions
until something binds it to a subject.

### Bindings: who can do it, and where

A **binding** connects subjects to a role:

- **RoleBinding** — grants a Role (or a ClusterRole) **in one namespace**. Binding a
  *ClusterRole* via a RoleBinding is a powerful, common pattern: define the
  permissions once cluster-wide, grant them scoped to a namespace.
- **ClusterRoleBinding** — grants a ClusterRole **across the whole cluster**. Use
  sparingly; this is how you accidentally give someone the keys to everything.

```text
   Subject (ServiceAccount / User / Group)
        │  bound by
        ▼
   RoleBinding ──references──► Role         → allowed verbs on resources IN a namespace
   ClusterRoleBinding ──────► ClusterRole   → allowed verbs on resources CLUSTER-WIDE
```

### Namespace-scoped vs cluster-scoped resources

Most things live in a namespace (Pods, Deployments, Services, Secrets, ConfigMaps,
Roles). Some are **cluster-scoped** (Nodes, Namespaces, PersistentVolumes,
ClusterRoles, StorageClasses). You can only grant access to cluster-scoped resources
with a **ClusterRole** — a namespaced Role can't name them.

### Testing access: `kubectl auth can-i`

You never have to guess. `kubectl auth can-i <verb> <resource>` answers for *you*;
`--as` **impersonates** any subject to check *their* effective access:

```text
kubectl auth can-i create deployments \
  --as=system:serviceaccount:my-app:cicd-deployer -n my-app   → yes / no
```

This is the single most useful RBAC debugging and verification tool.

### Design patterns

- **CI/CD ServiceAccount** — can deploy to *its* namespace (manage Deployments,
  ConfigMaps, Services) but **cannot** delete namespaces or read Secrets elsewhere.
- **Read-only auditor** — a ClusterRole with only `get`/`list`/`watch`, bound
  cluster-wide for dashboards and audits.
- **Namespace owner** — a team lead with broad rights **inside their namespace** via
  a RoleBinding to a capable ClusterRole, and nothing outside it.

---

## 2. Why it matters for platform engineering

- **You hand clusters to many teams.** RBAC is how you give each team autonomy in
  their namespace without letting them touch others' workloads or the control plane.
  It's the core multi-tenancy control.
- **Automation needs scoped identities.** Every pipeline, operator, and controller
  authenticates as a ServiceAccount. Over-privileged automation is a top real-world
  risk — a leaked CI token with `cluster-admin` is game over.
- **Least privilege limits blast radius.** When (not if) a credential leaks or a
  workload is compromised, tight RBAC is the difference between "one namespace
  affected" and "whole cluster owned."
- **Auditability.** Clear Roles and bindings make access reviewable — security and
  compliance ask "who can read Secrets in prod?" and RBAC should answer crisply.

---

## 3. Mental model

Think of RBAC as a four-part sentence that must be fully formed to allow an action:

```text
   [ SUBJECT ]  can  [ VERB ]  [ RESOURCE ]  in  [ SCOPE ]
    who             get/create   pods/secrets     namespace / cluster
        \_________________  _________________/
                          \/
          Role / ClusterRole  = the (verb + resource) permissions
          RoleBinding / ClusterRoleBinding = attaches them to the SUBJECT + SCOPE

   No fully-formed sentence → DENY (default). There are no deny rules, only grants.
```

Rules to remember:

1. **Roles are permissions; bindings are grants.** Neither works without the other.
2. **Default-deny, additive-allow.** Grant the minimum; absence means no.
3. **ClusterRoleBinding = cluster-wide. Prefer a RoleBinding to a ClusterRole** to
   reuse permissions while staying namespace-scoped.

---

## 4. Minimal implementation

Watch default-deny in action, then grant exactly one capability. A fresh
ServiceAccount can do almost nothing:

```bash
kubectl create namespace my-app
kubectl create serviceaccount cicd-deployer -n my-app
kubectl auth can-i list deployments \
  --as=system:serviceaccount:my-app:cicd-deployer -n my-app        # → no
```

Grant it the ability to manage Deployments **in `my-app` only** — a Role plus a
RoleBinding:

```bash
kubectl create role deploy-manager -n my-app \
  --verb=get,list,watch,create,update,patch --resource=deployments.apps
kubectl create rolebinding cicd-deployer-binding -n my-app \
  --role=deploy-manager --serviceaccount=my-app:cicd-deployer
```

Now re-check — the same subject is allowed the granted verb, but still denied
everything you didn't grant:

```bash
kubectl auth can-i create deployments \
  --as=system:serviceaccount:my-app:cicd-deployer -n my-app        # → yes
kubectl auth can-i get secrets \
  --as=system:serviceaccount:my-app:cicd-deployer -n my-app        # → no (never granted)
kubectl auth can-i delete namespaces \
  --as=system:serviceaccount:my-app:cicd-deployer                  # → no (cluster-scoped)
```

That gap between "yes" for the one granted action and "no" for everything else *is*
least privilege.

---

## 5. Hands-on lab

You'll build a realistic **CI/CD ServiceAccount** that can deploy into its own
namespace but cannot read Secrets, delete the namespace, or touch other namespaces —
and you'll prove every one of those boundaries with `kubectl auth can-i`. Local kind
cluster only.

➡️ **[Start the lab: Least-privilege RBAC for CI/CD](./lab/README.md)**

---

## 6. Production considerations

- **Never give automation `cluster-admin`.** It's the most common and most dangerous
  shortcut. Scope CI/CD and operators to exactly the namespaces and verbs they need.
- **Disable default ServiceAccount token automounting.** Most Pods don't call the API;
  set `automountServiceAccountToken: false` so a compromised Pod has no cluster
  credential by default.
- **Avoid wildcards (`*`) in Roles.** `resources: ["*"]` or `verbs: ["*"]` grants far
  more than intended and silently expands as new resource types appear. Enumerate
  what you mean.
- **Review bindings regularly.** Audit "who can read Secrets / who has cluster
  bindings" on a schedule; RBAC drifts as teams request "just one more permission."
- **Integrate real identity.** In production, Users/Groups come from an OIDC provider
  (SSO), and you bind *groups* to roles so access follows your identity system, not
  hand-managed certs.
- **Layer policy on top.** RBAC says *who can submit* an object; admission policy
  (Phase 13) governs *what the object may contain*. You need both.

---

## 7. Common mistakes

- **Wildcard permissions.** — `verbs: ["*"]`/`resources: ["*"]` "to make it work"
  grants the keys to the kingdom and grows over time. *Fix:* list exact resources and
  verbs; add more only when a real need is proven.
- **Binding `cluster-admin` to a ServiceAccount.** — A leaked token then owns the
  cluster. *Fix:* purpose-built, minimal roles scoped with RoleBindings.
- **Relying on the `default` ServiceAccount.** — Workloads inherit an ambient,
  often over-broad identity with an auto-mounted token. *Fix:* give each workload its
  own ServiceAccount and disable token automount unless needed.
- **Confusing Role scope.** — Trying to grant access to Nodes/PVs/Namespaces with a
  namespaced Role (which silently can't), or using a ClusterRoleBinding when you meant
  one namespace. *Fix:* ClusterRole for cluster-scoped resources; RoleBinding-to-
  ClusterRole to stay namespaced.
- **Testing by trial and error in prod.** — Applying broad access, then narrowing
  "later" (which never happens). *Fix:* design minimal, verify with `auth can-i
  --as=` before granting.

---

## 8. Assessment

**Knowledge checks**

1. What's the difference between authentication and authorization in Kubernetes, and
   which one is RBAC?
2. Name the three kinds of subjects. Which one do workloads use?
3. What's the difference between a Role and a RoleBinding? Between a Role and a
   ClusterRole?
4. When must you use a ClusterRole rather than a Role?
5. How do you check whether a specific ServiceAccount can delete Pods in `prod`?

**Concept exercise**

> Explain how Kubernetes decides whether a CI pipeline is allowed to update a
> Deployment — **without using the words "RBAC," "Role," or "RoleBinding."** Describe
> the default-deny, grant-the-minimum model in your own words.

**Trade-off / debugging exercise**

> A teammate "fixed" a failing pipeline by binding its ServiceAccount to
> `cluster-admin` with a ClusterRoleBinding. The pipeline only ever deploys to the
> `payments` namespace. Explain the risk concretely and design the minimal
> replacement.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Authn establishes identity (who you are); authz decides if that identity may
  perform an action. RBAC is authorization.
- **Q2:** Users, Groups, and ServiceAccounts. Workloads (and in-cluster automation)
  use ServiceAccounts.
- **Q3:** A Role is a set of permissions; a RoleBinding grants a Role to subjects —
  permissions do nothing until bound. A Role is namespace-scoped; a ClusterRole is
  cluster-wide (or a reusable permission set, or required for cluster-scoped
  resources).
- **Q4:** To grant access to cluster-scoped resources (Nodes, Namespaces,
  PersistentVolumes, StorageClasses), to non-resource URLs, or to reuse one permission
  set across namespaces.
- **Q5:** `kubectl auth can-i delete pods --as=system:serviceaccount:prod:<name> -n
  prod`.
- **Trade-off:** `cluster-admin` lets a leaked or compromised pipeline token do
  *anything* in *every* namespace — read all Secrets, delete workloads, modify RBAC.
  Minimal replacement: a Role in `payments` granting only the verbs/resources the
  deploy needs (e.g. get/list/create/update/patch on `deployments.apps`, plus
  configmaps/services), and a RoleBinding to the pipeline's ServiceAccount in
  `payments` — no Secrets, no delete-namespace, no other namespaces. Verify with
  `kubectl auth can-i ... --as=`.

</details>

---

## 9. Further reading

- Kubernetes — [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- Kubernetes — [Authenticating](https://kubernetes.io/docs/reference/access-authn-authz/authentication/)
- Kubernetes — [Managing ServiceAccounts](https://kubernetes.io/docs/concepts/security/service-accounts/)
- Kubernetes — [Authorization overview](https://kubernetes.io/docs/reference/access-authn-authz/authorization/)
- Kubernetes — [`kubectl auth can-i`](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_auth/kubectl_auth_can-i/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 03.5 — Storage](../05-storage/)
· _Next:_ [Module 03.7 — Resource Management →](../07-resource-management/)
