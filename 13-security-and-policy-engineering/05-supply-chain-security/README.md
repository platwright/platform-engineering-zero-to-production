# Module 13.5 — Supply Chain Security

> You don't just run the code you wrote — you run **everything it depends on** and
> the **pipeline that built it**. A production image is mostly other people's code:
> base layers, a runtime, hundreds of transitive dependencies, assembled by a CI
> system that is itself attackable. Supply chain security is how the platform makes
> "only known-good, scanned, attested artifacts ship" a structural property of the
> paved road — not a chore each team has to remember.

**Estimated effort:** ~2 hours (theory + lab)
**You'll need:** [Module 02.5 · Container Security](../../02-containerization/05-container-security/),
Docker, and [Syft](https://github.com/anchore/syft),
[Grype](https://github.com/anchore/grype), and
[Cosign](https://github.com/sigstore/cosign) (installed in the lab).

## Learning objectives

By the end of this module you will be able to:

- Explain the **software supply chain** as an attack surface and name its common attacks
  (typosquatting, dependency confusion, malicious deps, build compromise).
- Place a build on the **SLSA** maturity ladder (levels 0–3) and say what each rung adds.
- Generate a **Software Bill of Materials (SBOM)** with Syft and explain why inventory is
  the precondition for everything else.
- Scan an artifact with **Grype**, fail a build on severity, and triage false positives.
- Attach a **provenance/SBOM attestation** with Cosign (verification is Module 13.6).

---

## 1. Concept

### You run everything you depend on

Earlier phases treated "your application" as the thing you secure. But a container ships
a base image, a runtime, system libraries, and — for a typical service — **hundreds of
transitive dependencies** you never chose. You wrote maybe 2% of the bytes in
production; the rest arrived through a **supply chain** of registries, base-image
maintainers, and the pipeline that assembled them.

That chain is an attack surface. The **SolarWinds** breach (2020) is the archetype:
attackers didn't exploit a CVE in the running app — they compromised the **build
system** and slipped a backdoor into a *signed* update thousands installed as trusted.
The lesson generalizes: **compromise the pipeline or a dependency and you don't need to
break the app — the app ships your code for you.**

### How supply chains get compromised

The same pattern appears at every link in the chain:

- **Typosquatting.** A malicious package named to look like a popular one (`reqeusts`
  for `requests`). One typo pulls attacker code with install-time execution.
- **Dependency confusion.** You depend on an *internal* `acme-utils`; an attacker
  publishes a *public* one with a higher version and a misconfigured resolver prefers it.
  Your build pulls the impostor.
- **Malicious transitive deps.** You vet your direct dependencies, but each pulls its
  own. A backdoor three levels deep — a hijacked maintainer, a poisoned release — ships
  without you ever naming it.
- **Build compromise.** The SolarWinds move: tamper with the builder, base image, or a
  build script so the *output* is malicious even though the source in Git is clean.

You can't audit every transitive dependency, so prevention alone can't cover this. The
platform leans on **inventory, scanning, and provenance** instead — the rest of this
module.

### SLSA: a maturity ladder for build integrity

**SLSA** (Supply-chain Levels for Software Artifacts, pronounced "salsa") grades how
trustworthy a build *process* is. Read it as a **maturity ladder** — each rung makes
tampering harder to hide:

```text
SLSA build levels — each rung adds tamper-resistance
────────────────────────────────────────────────────
 L0  No guarantees       no provenance; "just trust me"
 L1  Provenance          build records how it was made — but forgeable
 L2  Signed provenance   a hosted builder signs it — tampering now shows
 L3  Hardened builds     isolated, ephemeral, non-falsifiable provenance
```

The point isn't to hit L3 on day one — it's that "where did this come from?" moves from
an *unanswerable* question (L0) to a *verifiable fact* (L3), one rung at a time. The
platform moves every team up the ladder **by default**.

### SBOM: you can't secure what you can't inventory

Before you can scan, patch, or attest anything, you must answer a hard question: **what
is actually in this artifact?** A **Software Bill of Materials (SBOM)**
is the answer — a machine-readable inventory of every component and version in an image,
like the ingredient list on food packaging.

When the next Log4Shell-class CVE drops, the only question is *"are we affected, and
where?"* Without an inventory that's days of grepping; with an SBOM per artifact it's a
single query. **You cannot patch what you cannot see.** Two open formats dominate, and
the tooling speaks both:

- **SPDX** — a Linux Foundation / ISO standard (originally license-focused, now broad).
  This course's default.
- **CycloneDX** — an OWASP, security-first standard, widely used in vuln workflows.

The key move: generate the SBOM *at build time*, when you know exactly what went in.

### Inventory, scan, update, attest

Four activities turn the supply chain from a blind spot into a controlled pipeline
stage. The course-default tools are free and CI-friendly:

- **SBOM — Syft.** `syft <image> -o spdx-json` emits a full component inventory.
  (Module 02.5's Trivy can too; Syft is the dedicated generator this module uses.)
- **Scan — Grype.** `grype <image>` or `grype sbom:./sbom.json` matches your inventory
  against vulnerability databases and reports CVEs by severity — the same job as Trivy.
  The platform move either way: **scan in CI and fail the build on high/critical**.
- **Update — Dependabot / Renovate.** Most vulnerabilities live in *out-of-date*
  dependencies. Update bots open PRs as versions ship, so exposure to a known CVE is days,
  not quarters.
- **Attest — Cosign.** An **attestation** is a signed statement *about* an artifact —
  "this SBOM belongs to this exact image, and I built it." `cosign attest` attaches it in
  the registry. This module **generates** it; **Module 13.6 verifies and enforces** it.

---

## 2. Why it matters for platform engineering

- **A structural control, not a per-team chore.** No team can SBOM, scan, and attest
  every build by hand. The platform bakes all three into the paved road, so **every**
  artifact is covered by construction — the Nth team gets it for free.
- **Inventory is incident-response leverage.** "Are we affected by CVE-X?" is a
  board-level question during a zero-day. With SBOMs stored per artifact it's a query
  that returns in minutes — not a week of panic.
- **The pipeline is the control point.** Admission policy (Module 13.3) can reject an
  unsigned image, but the *facts* it checks — scan verdict, SBOM, provenance — are
  produced in CI, where the CI/CD phase and the security phase meet.
- **It closes the "we only secured runtime" gap.** Module 02.5's hardening protects the
  *running* container; it can't help if the artifact was malicious before it ran. Supply
  chain security guards what's allowed to *become* an artifact.
- **It maps to named, rising risk.** OWASP Kubernetes **K02 (supply chain)** and **K10
  (outdated components)** are exactly this module — the cross-cutting layer flagged in
  [Module 13.1](../01-security-principles/).

---

## 3. Mental model

Hold one picture: the **artifact's journey**, and the three facts the platform attaches
along the way.

```text
   SOURCE        BUILD          ARTIFACT       REGISTRY        DEPLOY
   (git)   ──►   (CI/CD)  ──►   (image)  ──►   (push +   ──►   (admission
     │            │               │            attach)          verifies)
     │       generate +      facts attach    attestations     Module 13.6
     │       scan here       to the image    travel with it   checks facts,
     ▼            │               │                │           admits ONLY
   pinned    ┌────────┐     ┌────────┐      ┌──────────┐       verified,
   deps,     │  SBOM  │     │ Grype  │      │  cosign  │       scanned
   Renovate  │ (Syft) │     │  scan  │      │  attest  │       artifacts
             └────────┘     └────────┘      └──────────┘
              what's?        vulns?          who built it?
```

Left to right: the platform attaches **inventory**, a **scan verdict**, and
**provenance** as the artifact is built, and those facts travel with it into the
registry. This module produces them; **Module 13.6 is the gate on the right** that
refuses anything whose facts don't check out — so "only known-good, scanned, attested
artifacts ship" is a property of the pipeline, not a hope.

---

## 4. Minimal implementation

Start with the gap, not the tool. Ask the uncomfortable question about any production
image:

```console
$ # Do you even know what's inside this image?
$ docker history --no-trunc python:3.12-slim | wc -l
19
$ # ...a count of layers, NOT the packages inside them.
```

`docker history` shows *layers*, not *contents*. You ran `pip install`; you don't know
the resulting 200+ packages, which carry CVEs, or whether any is a typosquat. Close
that blind spot in **two commands** — inventory, then scan:

```bash
# 1. Inventory: what is actually inside? (SBOM in SPDX JSON)
syft python:3.12-slim -o spdx-json=sbom.json

# 2. Scan that inventory for known vulnerabilities
grype sbom:./sbom.json
```

The first turns "I think it's fine" into a concrete component list; the second ranks it
by known CVEs. To make it a **gate** rather than a report, fail on severity:

```bash
# Exit non-zero (fails the CI job) if anything is High or Critical
grype sbom:./sbom.json --fail-on high
```

That single flag is the difference between "we scan" and "vulnerable images can't ship."
Wire it into the paved road once and every team inherits the gate. The lab adds triage
config and a signed SBOM attestation on top.

---

## 5. Hands-on lab

You'll build a deliberately non-distroless sample image, generate an SBOM with Syft,
scan it with Grype, fail the build on high/critical findings while triaging a false
positive, and attach a signed SBOM **attestation** with Cosign — the exact artifact
Module 13.6 will later verify at admission.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **The pipeline is the only place this scales.** Generate the SBOM, scan, and attest in
  CI on every build, as non-optional stages of the golden path. A capability that relies
  on engineers remembering to run a tool is not a capability.
- **Store SBOMs and attestations as artifacts.** Keep each one next to (or attached to)
  its image, keyed by digest. When a zero-day lands you query stored SBOMs — you don't
  re-scan the world.
- **Scan continuously, not just at build.** New CVEs land daily; an image that passed
  last week fails today. Re-scan registry images on a schedule so "clean at build"
  doesn't rot into "vulnerable in production."
- **Budget for triage; don't bypass the gate.** Real pipelines hit false positives and
  un-fixable transitive CVEs. Use an auditable ignore list with a reason and an expiry —
  never a blanket `--fail-on never`. A gate with a logged exception process stays
  trustworthy.
- **Pin and auto-update.** Pin dependencies and base-image digests for reproducible
  builds, then let Renovate/Dependabot move the pins forward on a bot's PR.

---

## 7. Common mistakes

- **"We hardened the container, so we're covered."** — Runtime hardening (Module 02.5)
  protects a *running* image; it does nothing about a malicious or vulnerable artifact.
  *Fix:* add build-time inventory, scanning, and provenance — guard the artifact, not
  just the process.
- **Scanning without an inventory.** — Running a scanner ad hoc and keeping nothing. When
  a CVE drops you can't answer "where are we affected?" *Fix:* store an SBOM per build so
  exposure is a query, not an archaeology dig.
- **Treating a clean scan as "secure."** — Scanners find *known* CVEs in *known*
  packages; they miss zero-days, logic flaws, and a cleverly named typosquat. *Fix:*
  combine scanning with provenance, pinned-and-updated deps, and signature verification.
- **Blanket-ignoring to make the build green.** — Disabling the gate or ignoring every
  finding to ship. *Fix:* triage specific CVEs with a documented reason and an expiry;
  keep the gate failing on everything else.
- **Generating attestations nobody verifies.** — Signing provenance and SBOMs that no
  admission control ever checks. *Fix:* pair generation (here) with enforced verification
  at admission (Module 13.6).

---

## 8. Assessment

**Knowledge checks**

1. Why is an SBOM the *precondition* for the rest of supply chain security? Give the
   concrete incident-response reason.
2. Describe the SolarWinds pattern in one sentence, and say which link in the chain was
   attacked — the running app, or something else.
3. What do SLSA levels 1, 2, and 3 each *add* over the rung below?
4. Grype and Trivy do largely the same job. What is the *platform* decision that matters
   more than which scanner you pick?
5. What does `cosign attest` produce, and which module actually *verifies* it?

**Concept exercise**

> Explain to a product team **why** you're adding two pipeline stages — one that
> inventories every artifact, one that records who built it from what — **without naming
> any tool.** Make the "when the next zero-day drops" argument land.

**Trade-off / debugging exercise**

> A team's build just started failing: Grype reports a Critical CVE in a transitive
> dependency, but no fixed version exists yet and a release is due today.
>
> What do you do *right now* to ship safely, how do you keep the gate trustworthy for
> every other build, and how would you make this policy next time instead of a scramble?

<details>
<summary>Discussion (open after you've answered)</summary>

- **SBOM as precondition:** you can't patch or scan components you can't enumerate; in an
  incident a stored SBOM turns "are we affected by CVE-X?" into a one-line query.
- **SolarWinds:** attackers compromised the *build pipeline* and shipped a backdoor in a
  signed update — the trusted artifact, not the running app, was the vector.
- **SLSA:** L1 adds *provenance* (how it was built); L2 adds a *signature* from a hosted
  builder so tampering is detectable; L3 adds *isolated, hardened builds* with
  non-falsifiable provenance.
- **Scanner choice:** the tool (Grype vs Trivy) barely matters; what matters is a
  **non-optional CI gate that fails on high/critical**, with stored results and triage.
- **`cosign attest`:** produces a signed attestation (an SBOM/provenance predicate)
  attached to the image; **Module 13.6** verifies it at admission.
- **Debugging:** triage the CVE, then add a *scoped, time-boxed* ignore rule with a reason
  (not a blanket bypass) so only this CVE passes while the gate still fails on everything
  else; let a bot bump it when a fix ships. Systematize it with an expiring exception list
  reviewed in CI.

</details>

---

## 9. Further reading

- SLSA — [Supply-chain Levels for Software Artifacts](https://slsa.dev/)
- Anchore — [Syft (SBOM generator)](https://github.com/anchore/syft) and
  [Grype (scanner)](https://github.com/anchore/grype)
- SBOM formats — [SPDX](https://spdx.dev/) and [CycloneDX](https://cyclonedx.org/)
- Sigstore — [Cosign](https://github.com/sigstore/cosign) and
  [keyless signing](https://docs.sigstore.dev/cosign/signing/overview/)
- CISA — [Software Bill of Materials (SBOM)](https://www.cisa.gov/topics/information-communications-technology-supply-chain-security/sbom)
- CISA — [ED 21-01: Mitigate SolarWinds Orion Code Compromise](https://www.cisa.gov/news-events/directives/ed-21-01-mitigate-solarwinds-orion-code-compromise)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 13.4 — Secret Management](../04-secret-management/)
· _Next:_ [Module 13.6 — Image Signing and Verification →](../06-image-signing-and-verification/)
