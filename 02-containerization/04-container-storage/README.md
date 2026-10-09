# Module 02.4 — Container Storage

> In Module 02.1 you saw an image is a stack of read-only layers. A running
> container adds one thin **writable layer** on top — and that layer is thrown away
> when the container is removed. That's deliberate, not a bug. This module explains
> why container storage is ephemeral and how **volumes**, **bind mounts**, and
> **tmpfs** give you durable (or intentionally temporary) state.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** [Module 02.1](../01-container-fundamentals/) and Docker. No cloud.

## Learning objectives

By the end of this module you will be able to:

- Explain **why** the container filesystem is ephemeral and what exactly is deleted
  on `docker rm`.
- Describe the **overlay2** model: read-only layers, a writable layer, and
  copy-on-write.
- Choose between **named volumes**, **bind mounts**, and **tmpfs** with reasons.
- Use `--mount` to attach storage and persist a real workload (a database).
- Reason about production data: backups, single-node risk, and orchestrator volumes.

---

## 1. Concept

### The writable layer is disposable by design

An image's layers are **read-only**. When you start a container, the runtime stacks
a single **writable layer** on top using a union filesystem (`overlay2`). Every file
you create or modify lands in that writable layer via **copy-on-write**: to change a
file from a lower layer, the runtime first copies it up, then edits the copy.

```text
            ┌─────────────────────────────┐  merged view the process sees
  overlay   │  /  (container root fs)     │
  merged    └─────────────────────────────┘
                    ▲            ▲
   writable  ┌──────┴──────┐     │  copy-on-write: edits copy a file UP here
   (upper)   │  RW layer   │─────┘  ← DELETED when the container is removed
             └─────────────┘
   image     ┌─────────────┐
   (lower)   │  layer C    │  read-only
             │  layer B    │  read-only   (shared between containers)
             │  layer A    │  read-only
             └─────────────┘
```

When you `docker rm` the container, that writable (`upperdir`) layer is deleted with
it. **Anything written only inside the container is gone.** This is a feature: images
stay immutable and reproducible, and containers become disposable — you can kill and
recreate them freely. But it means **state must live somewhere else.**

### Mounts: storage that lives outside the union filesystem

To keep data, you mount storage at a path so writes bypass the disposable layer.
There are three kinds:

- **Named volumes** — storage Docker manages under
  `/var/lib/docker/volumes/<name>/_data`, with a lifecycle **independent** of any
  container. Create once, attach to many containers over time. This is the
  **production default** for container-managed state: portable within a host,
  backup-friendly, and not coupled to a host path.
- **Anonymous volumes** — the same thing without a name (a random ID). Created by a
  `VOLUME` instruction in a Dockerfile or `-v /path` with no source. Useful rarely,
  and a common source of **sprawl** (see Common mistakes).
- **Bind mounts** — a specific **host path** mapped into the container
  (`type=bind,source=/host/path,target=/in/container`). The container sees the
  host's actual files. Perfect for local development (edit code on the host, see it
  live in the container); risky in production because it couples you to the host's
  layout and permissions (and SELinux relabeling, `:z`/`:Z`).
- **tmpfs** — an in-memory filesystem (`type=tmpfs`). Never written to disk, gone on
  stop. Ideal for secrets or scratch data you explicitly do **not** want persisted.

### `--mount` vs `-v`

Two syntaxes do similar things. Prefer `--mount` — it's explicit and fails loudly on
mistakes:

```bash
# Clear and self-documenting:
docker run --mount type=volume,source=pgdata,target=/var/lib/postgresql/data ...

# Terse and ambiguous (a typo'd source silently creates an anonymous volume):
docker run -v pgdata:/var/lib/postgresql/data ...
```

### Which one, when?

```text
Named volume  → persistent app state on a host (databases, uploads). Default for prod-on-a-host.
Bind mount    → local dev (live code), or mounting host config. Avoid for prod state.
Anonymous vol → almost never on purpose; usually an accident from VOLUME or a typo.
tmpfs         → secrets and scratch that must never touch disk.
No mount      → stateless apps that keep NO local state (the 12-factor ideal).
```

---

## 2. Why it matters for platform engineering

State is where a platform gets *dangerous*. Everything else is recoverable; lost
data often isn't.

- **"My data disappeared" is a top support ticket.** Usually it's no volume, an
  anonymous-volume pile-up, or a bind-mount permission problem. Knowing the model
  lets you diagnose it instantly.
- **Stateless vs stateful shapes the whole platform.** Good platforms push apps
  toward **statelessness** (12-factor) so containers are disposable and scalable,
  and treat genuine state as a special, carefully-operated concern (managed
  databases, replicated volumes, backups).
- **Local disk is a portability and reliability trap.** A named volume ties data to
  one node's disk. The moment you orchestrate across machines (Phase 3), you need
  network or replicated storage — which is why Kubernetes introduces PersistentVolumes,
  StorageClasses, and CSI drivers.
- **Backups and restores are platform features, not afterthoughts.** If the platform
  owns where state lives, the platform owns protecting it.

## 3. Mental model

```text
  A container = disposable compute over an immutable image.
  State must be parked OUTSIDE the disposable part.

     ┌──────────── container (disposable) ────────────┐
     │  image layers (RO) + writable layer (RW, lost  │
     │  on rm)                                         │
     │        │                                        │
     │   /var/lib/postgresql/data  ──mount──┐          │
     └──────────────────────────────────────┼─────────┘
                                             ▼
               ┌───────────────┐  ┌───────────────┐  ┌───────────┐
               │ named volume  │  │  bind mount   │  │  tmpfs    │
               │ (persists,    │  │ (host path,   │  │ (RAM,     │
               │  Docker-owned)│  │  dev-friendly)│  │  vanishes)│
               └───────────────┘  └───────────────┘  └───────────┘
```

One sentence: **the container is cattle; your data is not — mount it somewhere that
survives the container's death.**

## 4. Minimal implementation

Prove ephemerality, then fix it — the smallest possible demonstration.

```bash
# 1. Write inside the container's writable layer, then remove the container:
docker run --name e1 alpine sh -c 'echo hi > /data.txt; cat /data.txt'   # hi
docker rm e1
# The file lived in the disposable layer — it's gone with the container.

# 2. Mount a named volume so writes land OUTSIDE the union filesystem:
docker run --name e2 --mount source=mydata,target=/data alpine \
  sh -c 'echo hi > /data/hi.txt'
docker rm e2                                   # remove the container...
docker run --rm --mount source=mydata,target=/data alpine cat /data/hi.txt
# hi   ← the volume (and its data) outlived the container
```

That five-line contrast *is* the whole concept: the writable layer dies with the
container; a volume lives on its own. Everything else — databases, uploads, caches —
is this same move applied to real workloads. Clean up with `docker volume rm mydata`.

## 5. Hands-on lab

You'll run a PostgreSQL container **without** a volume and watch its data vanish on
recreate, then run it **with** a named volume and watch the data survive — the exact
difference between a demo and a database you can trust. You'll also try a bind mount
and a tmpfs mount.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **Prefer managed or replicated storage for real state.** A local named volume
  pins data to one node's disk; if that node dies, so does the data. Use managed
  databases or network/replicated volumes for anything you can't lose.
- **Back up volumes and test restores.** A backup you've never restored is a hope,
  not a backup. Automate both.
- **Avoid bind mounts for production state.** Host-path coupling, permission and
  SELinux issues, and non-portability bite at the worst time. Bind mounts are a
  development convenience.
- **Watch anonymous-volume sprawl.** `VOLUME` in a Dockerfile and `-v` typos create
  unnamed volumes that accumulate and waste disk. Audit with `docker volume ls` and
  prune deliberately.
- **Use tmpfs for secrets.** Mount sensitive material in memory so it never lands on
  disk in a layer or volume.
- **In Kubernetes this becomes PV/PVC/StorageClass + CSI.** Stateful workloads use
  StatefulSets and external volumes; the ephemeral-by-default principle is identical.

## 7. Common mistakes

- **Assuming the container filesystem persists.** — "It worked until I recreated the
  container." The writable layer is disposable. *Fix:* mount a volume for any state.
- **Keeping production data in a bind mount on a single host.** — Couples data to one
  machine's path and permissions, and it's unprotected. *Fix:* use managed/replicated
  storage with backups.
- **`VOLUME` in a Dockerfile creating silent anonymous volumes.** — They pile up and
  can't be overridden cleanly, and they surprise users. *Fix:* document the mount
  point and attach a **named** volume at `docker run` time instead.
- **Using `-v` and getting an anonymous volume from a typo.** — You think you bound a
  path but created orphan storage. *Fix:* use `--mount`, which errors on bad input.
- **Running `docker volume prune` without checking.** — It deletes volumes not
  currently attached — including data you wanted. *Fix:* `docker volume ls` and
  inspect/label first.
- **Writing secrets to the writable layer or baking them into the image.** — They
  persist and leak. *Fix:* tmpfs or a secrets mechanism (Module 02.5).

## 8. Assessment

**Knowledge checks**

1. Why is the container filesystem ephemeral, and what exactly is deleted on
   `docker rm`?
2. Give the key difference between a **named volume** and a **bind mount**, and a
   good use for each.
3. What is **tmpfs** for, and what happens to its contents when the container stops?
4. What is the `VOLUME`-instruction gotcha?
5. Where on the host does a **named volume** store its data?

**Concept exercise**

> Explain why a container loses its data when it's recreated, and how to prevent it,
> **without using the word "volume."** Describe the mechanism and the fix in your own
> words.

**Trade-off exercise**

> You're running a PostgreSQL database in a container on a single server. Would you
> back its data directory with a **named volume** or a **bind mount** to a host
> directory? Give two concrete reasons, and name one risk that remains either way.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Because writes go to a disposable writable (`upperdir`) layer stacked over
  the read-only image layers; `docker rm` deletes that writable layer, so anything
  written only there is lost.
- **Q2:** A named volume is Docker-managed storage with a lifecycle independent of
  containers (use it for app/database state); a bind mount maps a specific host path
  in (use it for local dev / live code / host config).
- **Q3:** An in-memory filesystem for secrets/scratch that must never persist; its
  contents are discarded when the container stops.
- **Q4:** `VOLUME` silently creates **anonymous** volumes that accumulate over time
  and can't be cleanly overridden — surprising sprawl. Prefer runtime named mounts.
- **Q5:** Under `/var/lib/docker/volumes/<name>/_data` on the Docker host.
- **Trade-off:** A **named volume** is usually better: it's decoupled from the host
  path, easier to back up/relocate, and avoids host permission/SELinux issues that
  bind mounts hit. A bind mount gives you a known host path (handy for existing
  backup tooling). Remaining risk either way: the data still lives on **one node's
  disk** — if that node is lost, so is the data unless you replicate/back it up.

</details>

## 9. Further reading

- Docker — [Manage data in containers (storage overview)](https://docs.docker.com/storage/)
- Docker — [Volumes](https://docs.docker.com/storage/volumes/) and
  [Bind mounts](https://docs.docker.com/storage/bind-mounts/)
- Docker — [Storage drivers and `overlayfs`](https://docs.docker.com/storage/storagedriver/)
- Kubernetes — [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [The Twelve-Factor App — backing services & processes](https://12factor.net/backing-services)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [02.3 — Container Networking](../03-container-networking/)
· _Next:_ [02.5 — Container Security →](../05-container-security/)
