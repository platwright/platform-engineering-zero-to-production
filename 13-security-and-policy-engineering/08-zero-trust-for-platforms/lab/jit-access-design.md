<!-- markdownlint-disable MD033 -->
# JIT access & zero-standing-privileges design

> Worksheet. Design time-boxed, audited elevation for human operators so that **no
> one holds standing cluster-admin**. Replace every `<placeholder>`. Pair this with
> the least-privilege RBAC from Module 13.2.

## 1. Baseline (zero standing privileges)

- Default role for every engineer: `<e.g. namespace view-only in their team's ns>`
- Who, if anyone, holds standing elevated access and why it's justified: `<ideally "no one">`
- Where the baseline is defined as code: `<repo / path>`

## 2. The elevation request

| Field | Value |
|-------|-------|
| What can be requested | `<e.g. edit on team-apps for debugging; never cluster-admin>` |
| Who may request | `<role/group>` |
| Required justification | `<reason + ticket/incident link>` |
| Max duration (TTL) | `<e.g. 60 minutes>` |

## 3. Approval

- Approver(s): `<role — e.g. on-call lead; not the requester>`
- Auto-approve conditions (if any): `<e.g. active SEV incident>`
- Break-glass path (rare, loud, logged): `<how an emergency bypass works and who is paged>`

## 4. Mechanism

- How the grant is created: `<e.g. a controller creates a time-boxed RoleBinding>`
- How it expires: `<TTL / controller revokes at expiry>`
- Tooling: `<access-request tool / webhook / platform feature>`

## 5. Audit

- What is logged: `<who, what, when, why, approver, duration>`
- Where logs go: `<audit log sink / SIEM — ties to Module 13.2 audit logging + Phase 11>`
- Review cadence: `<e.g. weekly review of all elevations>`

## 6. Blast-radius check

- If a requester's laptop is compromised while a grant is active, what can the
  attacker reach? `<answer>`
- How does the TTL + scope limit that compared to standing cluster-admin? `<answer>`
