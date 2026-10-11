<!-- markdownlint-disable MD033 -->
# Platform-API Design Worksheet

> Fill in each section for your chosen platform (real or HelloCorp). Replace every
> `<placeholder>` with your own content. Keep this document — it is the architecture
> you implement in Modules 15.2–15.8 and assemble in Project 4.

- **Subject (org / platform):** `<name>`
- **Author:** `<your name>`
- **Date:** `<yyyy-mm-dd>`
- **Golden path being designed:** `<e.g. standard Go microservice>`

## 1. Five planes → components

| Plane | Component / capability | Build, buy, or OSS? | Already built in |
|-------|------------------------|---------------------|------------------|
| Developer control | `<e.g. Backstage + platform CLI>` | `<decision>` | This phase |
| Integration & delivery | `<e.g. GitHub Actions + ArgoCD>` | `<decision>` | `<phase>` |
| Resource | `<e.g. Terraform / Crossplane>` | `<decision>` | `<phase>` |
| Monitoring | `<e.g. Prometheus / Grafana / OTel>` | `<decision>` | `<phase>` |
| Security | `<e.g. ESO + RBAC + policy>` | `<decision>` | `<phase>` |

## 2. Orchestration sketch

> Show how ONE "new service" request fans out across the planes. Mark where the
> platform API sits and where the orchestration glue lives.

```text
DEVELOPER
   │ "<the request in one sentence>"
   ▼
INTERFACE: <portal / CLI / CI>
   ▼
PLATFORM API: <spec kind + version>
   ▼
ORCHESTRATION: <what sequences the planes>
   ├─ delivery:   <what happens>
   ├─ resource:   <what happens>
   ├─ monitoring: <what happens>  (always-on)
   └─ security:   <what happens>  (always-on)
```

## 3. Platform API — `ServiceRequest` spec

> Versioned from day one. Mark optional fields with their default. Mark always-on
> conventions that are NOT developer choices.

```yaml
apiVersion: <platform.example.com/v1>
kind: ServiceRequest
metadata:
  name: <service-name>          # required
  owner: <team>                 # required
spec:
  language: <go|python|...>      # required
  path: <golden-path-name>       # required
  environments:                  # optional, default: [dev]
    - name: <env>
      resources:
        - type: <postgres|redis|...>   # optional
          size: <small|medium|large>   # optional, default: small
  # Always-on conventions (NOT parameters a developer sets):
  #   observability: default dashboard + alerts
  #   security: secret injection + least-privilege RBAC + non-root, signed image
```

- **Required fields (developer must supply):** `<list>`
- **Optional fields (have defaults):** `<list>`
- **Always-on conventions (platform supplies):** `<list>`

## 4. Build-vs-buy matrix

> Score each 1–5 (5 = high). Then record a decision and a one-line justification.

| Component | Differentiation | Op cost | Time-to-value | Lock-in | Decision | Why |
|-----------|-----------------|---------|---------------|---------|----------|-----|
| `<portal>` | `<1-5>` | `<1-5>` | `<1-5>` | `<1-5>` | `<build/buy/OSS>` | `<reason>` |
| `<catalog>` | `<1-5>` | `<1-5>` | `<1-5>` | `<1-5>` | `<build/buy/OSS>` | `<reason>` |
| `<golden-path orchestration>` | `<1-5>` | `<1-5>` | `<1-5>` | `<1-5>` | `<build/buy/OSS>` | `<reason>` |
| `<secrets>` | `<1-5>` | `<1-5>` | `<1-5>` | `<1-5>` | `<build/buy/OSS>` | `<reason>` |

**Heuristic check:** did you *build* where you differentiate (paths, orchestration)
and *buy/adopt* the commodities (portal, catalog)? `<yes/no — explain>`

## 5. Escape hatch and migration

- **One legitimate deviation the path must allow:** `<e.g. a custom base image>`
- **How it stays visible and auditable:** `<e.g. a typed, default-off, logged input>`
- **Shipping a breaking API v2 without breaking teams:** `<deprecation window + bump
  tooling + migration guide>`

---

### Self-check

- [ ] Every plane maps to a component, not a ticket.
- [ ] The API is versioned and declarative.
- [ ] Monitoring and security are conventions, not optional parameters.
- [ ] Each build-vs-buy call has a one-line justification.
- [ ] There is a named escape hatch and a migration story.
