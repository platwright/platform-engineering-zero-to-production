# `scripts/`

Repository-wide helper scripts.

| Script | What it does |
|--------|--------------|
| [`check-prerequisites.sh`](./check-prerequisites.sh) | Reports which course tools are installed (Linux/macOS/WSL2). |
| [`check-prerequisites.ps1`](./check-prerequisites.ps1) | The same check for Windows PowerShell. |

## Usage

Linux / macOS / WSL2:

```bash
chmod +x scripts/check-prerequisites.sh
./scripts/check-prerequisites.sh
```

Windows (PowerShell):

```powershell
./scripts/check-prerequisites.ps1
```

Both scripts are informational. They print the version of each tool that's
installed, flag any missing **core** tool, and exit non-zero if a core tool is
missing (handy in CI or a `make check`). They never install anything.

See [`00-orientation/environment-setup.md`](../00-orientation/environment-setup.md)
for installation instructions.
