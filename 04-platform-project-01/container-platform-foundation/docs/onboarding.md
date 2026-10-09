# Onboarding a new team onto the platform foundation

> This is the runbook the platform team follows to bring a new stream-aligned team
> onto the Container Platform Foundation. In Pass 1 it's a short, well-documented
> manual procedure; the goal in later phases is to make it **self-service** (a
> template or a `platform team create` command), so no one waits on a ticket.

## Outcome

A new team (say, `team-c`) gets:

- an isolated namespace with the `restricted` Pod Security Standard enforced,
- least-privilege RBAC for its members and a narrow CI deployer ServiceAccount,
- a LimitRange and ResourceQuota, and
- the ability to deploy a hardened workload immediately.

## Procedure

1. **Create the namespace** (copy the `team-a` block from
   [`00-namespaces.yaml`](../kubernetes/platform/00-namespaces.yaml), rename to
   `team-c`, keep the Pod Security labels):

   ```bash
   kubectl create namespace team-c
   kubectl label namespace team-c \
     platform.example.com/team=team-c \
     platform.example.com/environment=dev \
     pod-security.kubernetes.io/enforce=restricted \
     pod-security.kubernetes.io/warn=restricted \
     pod-security.kubernetes.io/audit=restricted
   ```

2. **Apply guardrails** (copy the `team-a` LimitRange and ResourceQuota, change the
   namespace to `team-c`, apply). Adjust the quota to the team's agreed budget.

3. **Apply RBAC** (copy [`30-rbac-team-a.yaml`](../kubernetes/platform/30-rbac-team-a.yaml),
   replace `team-a` with `team-c` and `Group: team-a` with `Group: team-c`, apply).

4. **Verify isolation and least privilege:**

   ```bash
   kubectl auth can-i create deployments -n team-c \
     --as=system:serviceaccount:team-c:ci-deployer         # yes
   kubectl auth can-i get pods -n team-a \
     --as-group=team-c --as=carol                          # no
   ```

5. **Hand over the golden path.** Point the team at
   [`team-a-hello.yaml`](../kubernetes/apps/team-a-hello.yaml) as the hardened
   starting template, and at the [build guide](../build-guide.md).

6. **Record it.** Add the team to your catalog/spreadsheet (owner, quota, contact).

## Definition of done

- [ ] Namespace exists with `restricted` enforcement.
- [ ] LimitRange + ResourceQuota applied and sized.
- [ ] RBAC verified (team can manage its namespace; cannot touch others).
- [ ] CI deployer ServiceAccount verified (can deploy; cannot escalate).
- [ ] Team can deploy the hardened sample and reach it.

## Make it self-service (later)

Doing this by hand per team is Pass 1. The platform-engineering move is to turn this
runbook into a **template** (a Backstage software template or a CLI command) so a
team onboards itself in minutes. That's the subject of
[Phase 12 · Developer Experience & IDP](../../../15-developer-experience-and-idp/)
and [Capstone 2](../../../21-capstone-projects/). Until then, keep this runbook
tight and fast.
