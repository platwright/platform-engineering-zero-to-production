<!-- markdownlint-disable MD033 -->
# Worksheet — Build a container by hand

Fill this in as you work through the lab. Replace each `<...>` with what you
observe. Keep it — it's evidence that you understand the container primitives.

## 1. Host baseline (step 1)

- Kernel (`uname -r`): `<...>`
- Host hostname: `<...>`
- Host namespace IDs from `/proc/self/ns`:
  - `pid`: `<...>`
  - `uts`: `<...>`
  - `mnt`: `<...>`
  - `net`: `<...>`

## 2. By-hand namespaces (steps 2–5)

- Hostname set inside the UTS namespace: `<...>`
- Did the host hostname change in the second terminal? `<yes / no>`
- Your PID inside the new PID namespace (from `ps -e`): `<...>`
- How many processes could you see inside? `<...>`
- In the NET namespace, which interfaces did `ip addr` show? `<...>`
- Namespace IDs inside vs. host — which differed?
  - `pid`: `<inside>` vs `<host>`
  - `uts`: `<inside>` vs `<host>`
  - `net`: `<inside>` vs `<host>`

## 3. cgroups and the OOM kill (steps 6–7)

- `memory.max` you set: `<...>`
- `memory.current` before any process joined: `<...>`
- Exit code of the OOM-killed Docker container: `<...>`
- `State.OOMKilled` from `docker inspect`: `<...>`

## 4. Docker comparison (step 8)

- Hostname inside the Docker container: `<...>`
- Your PID inside the Docker container: `<...>`
- Did `eth0` exist and was it UP? `<...>`
- What did Docker add on top of the raw namespaces?
  - `<e.g. a configured network interface>`
  - `<e.g. a root filesystem from an image>`

## 5. One-sentence summary

> Docker automated these kernel features for me: `<...>`, `<...>`, and `<...>`.
