# Lab — Build the `platform` CLI (Go + Cobra)

> Build a real `platform` CLI in Go + Cobra with `env`, `deploy`, `logs`, and
> `version` subcommands and Viper-based config. The handlers are thin stubs that show
> where the platform-API call goes — the lesson is the structure and the thin-client
> discipline. Runs entirely locally.

**Estimated time:** ~45–60 minutes
**Type:** Build
**Deliverable:** A compiling `platform` CLI you can run locally, with subcommands,
flags, config precedence, and completions.

## Objectives

- Build and run a multi-command Cobra CLI.
- Wire Viper config with flag > env > file > default precedence.
- Keep every handler a thin wrapper over an API call.

## Prerequisites

- [Module 15.7](../README.md) and **Go 1.22+** (`go version`).
- The starter module in [`platform-cli/`](./platform-cli/): `go.mod`, `main.go`, and
  the [`cmd/`](./platform-cli/cmd/) package.
- Network access the first time (to download Cobra and Viper).

## Steps

1. **Read the structure.** Open [`platform-cli/`](./platform-cli/). Note the layout:

   - [`main.go`](./platform-cli/main.go) — calls `cmd.Execute()`, nothing else.
   - [`cmd/root.go`](./platform-cli/cmd/root.go) — the root command, persistent flags,
     and Viper config (`~/.platform/config.yaml`, env vars `PLATFORM_*`).
   - [`cmd/env.go`](./platform-cli/cmd/env.go) — `env list` and `env create`.
   - [`cmd/deploy.go`](./platform-cli/cmd/deploy.go) and
     [`cmd/logs.go`](./platform-cli/cmd/logs.go) — `deploy` and `logs`.
   - [`cmd/version.go`](./platform-cli/cmd/version.go) — `version` (set via `-ldflags`).

2. **Build it:**

   ```bash
   cd platform-cli
   go mod tidy   # first time only: downloads cobra + viper
   go build -o platform .
   ```

3. **Run the subcommands:**

   ```bash
   ./platform --help
   ./platform version
   ./platform env list
   ./platform env create --name my-feature-env --base dev
   ./platform deploy --app my-service --version sha-abc123 --env dev
   ./platform logs --app my-service --since 1h
   ```

   Each handler prints what request it *would* send — the real work lives behind the
   platform API.

4. **Exercise config precedence.** Create `~/.platform/config.yaml` with
   `default_env: staging` and `api_url: https://platform.example.com`, then compare:

   ```bash
   ./platform deploy --app x --version v1                 # uses file: staging
   PLATFORM_DEFAULT_ENV=prod ./platform deploy --app x --version v1   # env wins
   ./platform deploy --app x --version v1 --env dev       # flag wins
   ```

   Confirm the order flag > env var > file > default.

5. **Generate shell completions** (a free Cobra feature):

   ```bash
   ./platform completion zsh   # or bash / fish / powershell
   ```

6. **Confirm the thin-client discipline.** Read each handler: it parses input, resolves
   config, and prints the request. Note that none of them orchestrate anything — that
   is deliberate. Find the comment in `deploy.go` explaining why the CLI must not apply
   manifests itself.

## Expected result

A working `platform` binary: `./platform --help` lists `env`, `deploy`, `logs`, and
`version`; subcommands validate required flags and honour config precedence; and
completions generate. Every handler is a thin stub over an API call.

## Cleanup

> Remove the local build artifact. No cloud resources are created.

```bash
rm -f platform                 # the binary you built with -o platform
rm -f ~/.platform/config.yaml  # if you created the test config
# Keep go.mod/go.sum — they are the module's dependency lock, not build artifacts.
```

## Reflection

- How much code would `deploy` need if it *did* orchestrate GitOps itself — and who
  else would then have to reimplement that logic?
- Which of these commands would you actually build first for your org, and why that
  one?
- How is this CLI "another door" to the same platform API Backstage uses?

## Stretch goals (optional)

- Add a `--output json` flag so commands are script-friendly.
- Add a `platform cost --team <t> --month current` command (another thin wrapper).
- Wire a real HTTP call in `env list` against a mock server and render the JSON.
- Add a `GoReleaser` config (`.goreleaser.yaml`) to cross-compile and publish releases.
