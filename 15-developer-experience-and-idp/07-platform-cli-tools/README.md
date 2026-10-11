# Module 15.7 — Platform CLI Tools

> A portal is one interface to the platform; a **CLI** is the other — and for many
> developers, the one they live in. [Module 01.4](../../01-platform-foundations/04-the-internal-developer-platform/)
> said the platform API is the product and the portal is just a client; the CLI is a
> second client of that same API. This module covers when to build a CLI, the Go +
> Cobra + Viper stack, the commands a platform CLI offers, distribution and config, and
> the discipline that keeps it thin: **the CLI wraps API calls, not business logic.**

**Estimated effort:** ~2 hours (theory + lab)
**You'll need:** [Module 15.1](../01-idp-architecture/) (the platform API) and **Go
1.22+**. The lab builds a real CLI locally.

## Learning objectives

By the end of this module you will be able to:

- Decide when a CLI is the right interface for a platform task.
- Structure a CLI in **Go + Cobra + Viper** with subcommands and config.
- Design `platform env`, `platform deploy`, and `platform logs` commands.
- Explain distribution, versioning, config precedence, and shell completions.
- Keep the CLI a **thin client** of the platform API.

---

## 1. Concept

### Why a CLI, when you have a portal

A portal is great for discovery, browsing, and one-off actions. But developers work in
a terminal, and the highest-friction tasks are **frequent and repetitive**: spin up an
environment, deploy a version, tail logs, check cost. For those, a CLI is faster than
clicking, scriptable in CI, and composable with the rest of the shell. It is the same
move as every other interface in this phase — meet developers where they already are
and remove friction (Module 01.3).

Crucially, the CLI is **another client of the platform API** (Module 15.1), not a
separate platform. Portal, CLI, and CI all produce or consume the same declarative
requests; the CLI just happens to be the terminal-shaped door. Build one **when a task
is frequent enough that the terminal beats the portal** — not reflexively.

### The stack: Go + Cobra + Viper

The de facto standard for platform CLIs (kubectl, helm, gh, argocd are all built this
way) is:

- **Go** — single static binary, cross-compiles to every OS/arch, trivial to
  distribute (no runtime to install).
- **[Cobra](https://cobra.dev/)** — the command framework: subcommands, flags, args,
  help, and shell completions, all generated for you.
- **[Viper](https://github.com/spf13/viper)** — configuration: merges flags, env vars,
  and config files with a clear precedence, so `--env`, `PLATFORM_ENV`, and
  `~/.platform/config.yaml` all work.

```text
   platform <command> <subcommand> [flags]
   └── Cobra: parses, routes, validates, --help, completions
        └── your handler: build a request, call the platform API, print the result
             └── Viper: resolves config (flag > env > file > default)
```

### The command surface

A platform CLI mirrors the platform's capabilities as verbs a developer thinks in:

```bash
platform env list
platform env create --name my-feature-env --base dev
platform deploy --app my-service --version sha-abc123 --env dev
platform logs --app my-service --env prod --since 1h
platform cost --team payments --month current
```

Notice the shape: **noun → verb → flags** (`env create`, not `create-env`). Each command
maps to a platform-API call — `env create` POSTs an environment request; `deploy` sends
a deployment request that GitOps fulfils (Phase 8); `logs` proxies to the logging
backend (Phase 11); `cost` queries FinOps data (Phase 15). The CLI is a **friendly
façade over the API**, nothing more.

### Config: flags, env vars, and a config file

Viper gives a predictable precedence so the CLI behaves well both interactively and in
automation:

```text
highest  ──►  command-line flag         (--env prod)
             environment variable       (PLATFORM_ENV=prod)   ← great for CI
             config file                (~/.platform/config.yaml)
lowest   ──►  built-in default
```

```yaml
# ~/.platform/config.yaml
api_url: https://platform.internal.example.com
default_env: dev
team: payments
```

A developer sets their team once in the file; CI overrides with env vars; a one-off run
overrides with a flag. Same binary, no surprises.

### Distribution, versioning, and auto-update

A CLI has users, so it is a product (the recurring theme). Ship it like one:

- **Distribution.** Publish cross-compiled binaries to **GitHub Releases**, a
  **Homebrew tap** (`brew install your-org/tap/platform`), or an internal package
  manager/registry. [GoReleaser](https://goreleaser.com/) automates building and
  publishing all platforms from one tag.
- **Versioning.** Embed the version at build time (`platform version`), and check for
  updates so users are not stranded on an old build. Breaking changes to flags or
  output are versioned like any API (Module 06.4).
- **Shell completions.** Cobra generates **bash, zsh, and fish** completions for free —
  a big DX win (`platform completion zsh`). Ship them.

### The cardinal rule: wrap the API, do not become it

The single most important design discipline: **the CLI contains no business logic.** It
parses input, calls the platform API, and formats output. All the real work —
provisioning, deployment orchestration, policy — lives behind the API (Module 15.1),
where the portal and CI reach it too. The moment the CLI starts doing orchestration
itself, you have logic that only terminal users get, that CI and the portal cannot
reuse, and that you must reimplement elsewhere. Keep it thin.

---

## 2. Why it matters for platform engineering

The CLI is the interface that proves the API-first principle pays off. If your platform
API is well-designed (Module 15.1), adding a CLI is a weekend of Cobra scaffolding — a
thin client over endpoints that already exist. If it is *not* — if logic lives in the
portal — the CLI either can't be built or duplicates that logic, and you feel the design
debt immediately. Building the CLI is a test of whether you really built a platform API
or just a portal.

It is also where a lot of developer goodwill is earned. `platform deploy --app x
--version y --env dev` from a terminal or a CI job, with completions and sane config, is
the kind of frictionless tool that drives adoption — the scoreboard from Module 01.1.
In Project 4, this CLI sits beside Backstage as the second door to the same platform.

---

## 3. Mental model

```text
     PLATFORM CLI = a thin, terminal-shaped CLIENT of the platform API
     ────────────────────────────────────────────────────────────────

   Go (static binary) + Cobra (commands) + Viper (config)
   shape:  noun → verb → flags     (env create, deploy, logs, cost)
   config: flag > env var > ~/.platform/config.yaml > default
   ship:   GitHub Releases / Homebrew / GoReleaser · completions · `version`
   RULE:   wrap API calls, NEVER business logic  (logic lives behind the API,
           where the portal and CI reach it too)

   One line: another door to the SAME platform API — thin, fast, scriptable.
```

One sentence: **a platform CLI is a thin Cobra client that turns terminal commands into
platform-API calls — a second interface to the product, never a second implementation.**

---

## 4. Minimal implementation

The smallest real CLI is a Cobra root command with one subcommand. `main.go` just
executes the root:

```go
// main.go
package main

import "github.com/your-org/platform-cli/cmd"

func main() {
    cmd.Execute()
}
```

```go
// cmd/root.go (abridged)
package cmd

import (
    "github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
    Use:   "platform",
    Short: "The platform CLI — a thin client of the platform API",
}

func Execute() {
    cobra.CheckErr(rootCmd.Execute())
}
```

```go
// cmd/env.go (abridged) — `platform env list`
package cmd

import (
    "fmt"

    "github.com/spf13/cobra"
)

var envCmd = &cobra.Command{Use: "env", Short: "Manage environments"}

var envListCmd = &cobra.Command{
    Use:   "list",
    Short: "List environments",
    RunE: func(cmd *cobra.Command, args []string) error {
        // In a real CLI: call the platform API and print the result.
        fmt.Println("dev\nstaging\nprod")
        return nil
    },
}

func init() {
    envCmd.AddCommand(envListCmd)
    rootCmd.AddCommand(envCmd)
}
```

That compiles into a single `platform` binary with `--help`, subcommands, and
completions, all for free. The handler's one job is "call the API, print the result" —
the lab fleshes out `env`, `deploy`, and `logs` with flags, Viper config, and a
`version` command, keeping every handler a thin wrapper.

---

## 5. Hands-on lab

You will build a `platform` CLI in Go + Cobra: a [`main.go`](./lab/platform-cli/main.go),
a [`cmd/`](./lab/platform-cli/cmd/) package with `env` (list/create), `deploy`, `logs`,
and `version` subcommands, Viper-based config from `~/.platform/config.yaml`, and a
[`go.mod`](./lab/platform-cli/go.mod). The handlers are stubs that show where the API
call goes — the point is the structure and the thin-client discipline. You will build
and run it locally.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Keep it thin.** No orchestration or policy in the CLI — only input, API call,
  output. Logic in the CLI is logic the portal and CI cannot reuse.
- **Version and auto-update.** Embed the build version, expose `platform version`, and
  nudge users off stale builds. Version breaking flag/output changes like an API.
- **Config precedence must be predictable.** Flag > env var > file > default, so the CLI
  behaves identically for humans and in CI. Document it.
- **Authenticate like everything else.** The CLI should use the org's SSO/OIDC, not a
  bespoke token scheme. It is a client of the same API the portal secures.
- **Ship completions and good `--help`.** These are cheap DX wins that drive adoption;
  Cobra generates them.
- **Automate releases.** GoReleaser + a tag → binaries for every OS/arch, a Homebrew
  tap, and checksums. Manual release builds rot.
- **Output for both humans and machines.** A `--output json` mode makes the CLI usable
  in scripts and CI, not just at a prompt.

---

## 7. Common mistakes

- **Business logic in the CLI.** Orchestration that only terminal users get and CI/the
  portal cannot reuse. *Fix:* wrap the platform API; keep logic behind it.
- **Over-engineering a tool nobody asked for.** A sprawling CLI for rare tasks. *Fix:*
  build commands for *frequent* friction; let the portal handle the rest.
- **Inconsistent config.** Flags, env, and file disagree or have murky precedence.
  *Fix:* Viper with documented precedence (flag > env > file > default).
- **No versioning or update path.** Users stuck on old builds with broken assumptions.
  *Fix:* embedded version, `version` command, update check, versioned changes.
- **Hand-built, hand-shipped releases.** Slow, error-prone, missing platforms. *Fix:*
  GoReleaser from a tag.
- **Reinventing auth.** A custom token file instead of org SSO. *Fix:* reuse the
  platform's identity (OIDC), least-privilege.

---

## 8. Assessment

**Knowledge checks**

1. Why is "the CLI wraps API calls, not business logic" the cardinal rule?
2. What do Cobra and Viper each provide, and why Go for the binary?
3. What is the config precedence a platform CLI should follow, and why does env-var
   support matter for CI?
4. Name two distribution methods and what `platform version` plus an update check buys
   you.

**Concept exercise**

> Explain why a platform should expose a CLI *and* a portal **without calling either
> "the platform."** Describe what they share and why neither is the product itself.

**Architecture / trade-off exercise**

> A teammate wants `platform deploy` to compute the deployment plan, pick the target
> cluster, and apply manifests directly from the CLI "to avoid a round-trip to the
> API." Explain what is wrong with this using the API-first principle, what breaks for
> CI and the portal, and how you would implement `deploy` instead.

<details>
<summary>Discussion</summary>

- **Q1:** Because logic in the CLI is only available to terminal users; the portal and
  CI cannot reuse it, and you would have to reimplement it. Keeping logic behind the API
  means every interface shares one implementation.
- **Q2:** Cobra provides the command framework (subcommands, flags, help, completions);
  Viper provides layered configuration (flags/env/file). Go gives a single static,
  cross-compiled binary with no runtime to install.
- **Q3:** Flag > environment variable > config file > default. Env-var support lets CI
  set config (`PLATFORM_ENV=prod`) without files or interactive flags, so the same
  binary works for humans and pipelines.
- **Q4:** GitHub Releases, a Homebrew tap, or an internal registry (GoReleaser
  automates all). `version` + update check keeps users off stale builds and lets you
  manage breaking changes.
- **Trade-off:** Putting plan/target/apply in the CLI moves business logic out of the
  API, so CI and the portal cannot reuse it and would need their own copy — the
  anti-pattern. Instead, `platform deploy` should send a declarative deployment request
  to the platform API, which orchestrates GitOps (Phase 8) to fulfil it; the CLI just
  submits and reports status.

</details>

---

## 9. Further reading

- [Cobra](https://cobra.dev/) — the Go CLI framework (used by kubectl, helm, gh)
- [Viper](https://github.com/spf13/viper) — configuration with flag/env/file precedence
- [GoReleaser](https://goreleaser.com/) — build and publish Go binaries for every
  platform
- [Command Line Interface Guidelines (clig.dev)](https://clig.dev/) — CLI UX principles
- Kubernetes — [kubectl](https://github.com/kubernetes/kubectl) and GitHub
  [cli/cli](https://github.com/cli/cli) as reference CLIs

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [15.6 — Golden Paths](../06-golden-paths/)
· _Next:_ [15.8 — Developer Portal Documentation →](../08-developer-portal-documentation/)
