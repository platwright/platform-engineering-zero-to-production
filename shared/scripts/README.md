# `shared/scripts/`

Helper scripts reused by more than one module or lab. Keep single-module scripts
inside that module's `lab/` directory; promote a script here only when it's shared.

Conventions:

- Bash scripts target Linux/macOS (and WSL2 on Windows); use `set -euo pipefail`.
- Keep scripts idempotent and safe to re-run.
- No secrets in scripts. Read configuration from environment variables or flags.

> General environment and prerequisite checks live in the top-level
> [`scripts/`](../../scripts/) directory.
