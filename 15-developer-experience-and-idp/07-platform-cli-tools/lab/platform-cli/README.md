# platform CLI (starter)

A thin, Cobra-based command-line client of the internal developer platform API. It is a
**starter skeleton** for Module 15.7: the command structure, flags, and Viper config are
real and compile; the handlers are stubs that show where each platform-API call goes.

## Design rule

The CLI **wraps API calls, not business logic.** Each handler parses input, resolves
config, builds a request, and (in a real build) calls the platform API — where the
portal and CI reach the same logic. No orchestration lives here.

## Layout

```text
platform-cli/
├── go.mod            # module + cobra/viper dependencies
├── main.go           # calls cmd.Execute()
└── cmd/
    ├── root.go       # root command, persistent flags, Viper config
    ├── env.go        # platform env list | create
    ├── deploy.go     # platform deploy
    ├── logs.go       # platform logs
    └── version.go    # platform version
```

## Build and run

```bash
go mod tidy
go build -o platform .
./platform --help
```

## Config

Config resolves with precedence **flag > environment variable > config file >
default**. The file lives at `~/.platform/config.yaml`:

```yaml
api_url: https://platform.internal.example.com
default_env: dev
```

Environment variables are read as `PLATFORM_<KEY>` (e.g. `PLATFORM_DEFAULT_ENV=prod`).

## Version

The version string is injected at build time:

```bash
go build -ldflags "-X github.com/your-org/platform-cli/cmd.version=1.2.3" -o platform .
```
