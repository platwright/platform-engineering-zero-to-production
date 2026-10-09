# Module 02.1 — Container Fundamentals

> A container is not a lightweight virtual machine and it is not magic. It is an
> ordinary Linux process that the kernel has been told to **isolate** (with
> namespaces) and **limit** (with cgroups). This module builds that understanding
> from the kernel up, so that every `docker run` later in the course is something
> you can reason about — and debug — rather than trust blindly.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** [Phase 1](../../01-platform-foundations/), Docker installed, and a Linux
shell (Windows users: **WSL2** — a real Linux kernel is required for the lab).

## Learning objectives

By the end of this module you will be able to:

- Explain a container as **a process plus namespaces plus cgroups**, not a VM.
- Describe what each namespace (`pid`, `net`, `mnt`, `uts`, `ipc`, `user`) isolates
  and what cgroups limit.
- Contrast containers and virtual machines and choose between them with reasons.
- Read the **OCI image** model — layers, manifest, and index — and the container
  lifecycle.
- Explain where the **container runtime interface (CRI)** and runtimes like
  `containerd` fit, and why containers reshaped platform engineering.

---

## 1. Concept

### A container is a process, isolated

Run a container and look for it from the host:

```bash
docker run -d --name demo nginx
ps aux | grep nginx   # on the host — there it is, a normal process
```

The nginx "container" is just a process (or a few) running on your host kernel.
There is **no guest operating system** inside it. What makes it feel like a separate
machine is that the Linux kernel shows that process a *restricted view* of the
system. Two kernel features do all the heavy lifting:

- **Namespaces** control **what a process can see** — which process IDs, which
  network interfaces, which filesystem, which hostname.
- **cgroups** (control groups) control **what a process can use** — how much CPU,
  memory, and I/O.

That's the whole trick. "Container" is a convenient word for *a process running in a
set of namespaces, constrained by cgroups, usually with its own root filesystem.*

### Namespaces — isolating what you can see

Linux provides several namespace types. A container typically gets its own set:

- **PID** — its own process-ID number space. Inside, your app is PID 1 and cannot
  see host processes. (This is why signal handling and "PID 1" behaviour matter.)
- **NET** — its own network stack: interfaces, routing table, firewall rules,
  ports. A container's `:80` is not the host's `:80` until you map it.
- **MNT** — its own mount table, so it sees its own root filesystem rather than the
  host's.
- **UTS** — its own hostname and domain name.
- **IPC** — its own System V IPC / POSIX message queues and shared memory.
- **USER** — its own user/group ID mapping, so root (UID 0) *inside* the container
  can map to an unprivileged UID on the host. This is a key security boundary.

You can see a process's namespaces as kernel links under `/proc`:

```bash
ls -l /proc/self/ns
# lrwxrwxrwx ... net -> 'net:[4026531992]'   <- the number identifies the namespace
```

Two processes with the **same** namespace number share that namespace; different
numbers mean they are isolated on that axis. A "container" is really just a process
whose namespace numbers differ from the host's.

### cgroups — limiting what you can use

Isolation alone isn't enough: one container could still starve the host of CPU or
memory. **cgroups** (now cgroup v2) arrange processes into a tree and enforce
**limits** and **accounting** on each branch:

```text
/sys/fs/cgroup/
└── mygroup/
    ├── memory.max      -> 100M   (hard memory cap; exceed it → OOM-killed)
    ├── cpu.max         -> 50000 100000  (50% of one CPU)
    └── cgroup.procs    -> 4812   (the PIDs that belong to this group)
```

This is exactly what Kubernetes `resources.requests/limits` compile down to later in
the course. When a pod is "OOMKilled", a cgroup `memory.max` is what killed it.

### Container vs virtual machine

Both isolate workloads, but at different layers:

```text
   Virtual machines                     Containers
 ┌───────────────────┐              ┌───────────────────┐
 │ App A  │  App B    │              │ App A  │  App B    │
 │ Bins/  │  Bins/    │              │ Bins/  │  Bins/    │
 │ Libs   │  Libs     │              │ Libs   │  Libs     │
 ├────────┼───────────┤              ├────────┴───────────┤
 │Guest OS│ Guest OS  │  ← full OS   │  (no guest OS)     │
 ├────────┴───────────┤    per VM    ├────────────────────┤
 │     Hypervisor     │              │ Container runtime  │
 ├────────────────────┤              ├────────────────────┤
 │      Host OS       │              │   Host OS kernel   │ ← shared kernel
 ├────────────────────┤              ├────────────────────┤
 │      Hardware      │              │      Hardware      │
 └────────────────────┘              └────────────────────┘
```

- **VMs** virtualize *hardware*; each runs a full guest OS kernel. Strong isolation,
  but heavier: GBs of image, seconds-to-minutes to boot.
- **Containers** virtualize the *operating system*; they **share the host kernel**.
  Lightweight: MBs, millisecond starts, high density — but the shared kernel is a
  weaker isolation boundary (a kernel exploit can cross it). That trade-off is why
  security (Module 02.5) matters and why sensitive multi-tenant workloads sometimes
  use VM-based sandboxes (gVisor, Kata, Firecracker).

### The OCI image: layers, manifest, index

A container needs a root filesystem. That comes from an **image**, standardized by
the **Open Container Initiative (OCI)**. An image is not one blob; it is:

- **Layers** — a stack of tar archives, each a filesystem diff. Layers are
  content-addressed (identified by a SHA-256 **digest**) and are overlaid at runtime
  (via `overlay2`) to form the final root filesystem. Because each layer is a
  diff, layers are **cached and shared** between images — pull once, reuse everywhere.
- **Config** — a JSON blob: the entrypoint, env, working dir, and the ordered list
  of layer digests.
- **Manifest** — a JSON document that ties the config and layers together for one
  platform (e.g. `linux/amd64`), referenced by its own digest.
- **Index** (a.k.a. manifest list) — an optional top-level document that maps
  *platforms* to manifests, so one tag can serve `amd64` and `arm64` (Module 02.7).

```text
tag: myapp:1.0  ─────────────▶  index (optional, multi-arch)
                                 ├─ linux/amd64 → manifest → config + [layerA, layerB, layerC]
                                 └─ linux/arm64 → manifest → config + [layerA, layerD, layerE]
```

The practical upshot: a **tag** (`:1.0`) is a human label that can move; a
**digest** (`@sha256:…`) is immutable and content-addressed. Platforms promote by
digest for exactly this reason (Module 02.6).

### Container lifecycle

A container moves through a small state machine; `docker`/`ctr`/`crictl` expose it:

```text
 (image) → create → [created] → start → [running] ⇄ pause/unpause → [paused]
                                   │
                                   ├─ stop  → SIGTERM, then SIGKILL → [exited]
                                   ├─ kill  → SIGKILL now           → [exited]
                                   └─ rm    → remove                → (gone)
```

`create` sets up namespaces, cgroups, and the filesystem but runs nothing; `start`
executes the entrypoint. Understanding this split explains a lot of real behaviour
(e.g. why a restart policy re-`start`s an existing container).

### Where the runtime fits: the CRI

"Docker" is actually several layers, and Kubernetes talks to a **standard interface**
rather than to Docker directly:

```text
 kubelet ──CRI (gRPC)──▶ containerd / CRI-O ──runc (OCI runtime)──▶ Linux kernel
                              │                                      (namespaces,
                         (manages images,                             cgroups)
                          snapshots, lifecycle)
```

- **OCI runtime** (`runc`, `crun`) — the low-level tool that actually calls
  `clone()` with the namespace flags and sets up cgroups to start the process.
- **High-level runtime** (`containerd`, `CRI-O`) — manages images, storage
  snapshots, and the lifecycle, and exposes the **CRI** (Container Runtime
  Interface) that the Kubernetes `kubelet` calls.

This is why Kubernetes "removing Dockershim" in 2022 changed little for most users:
Kubernetes was always driving a CRI runtime (`containerd`), and your OCI images run
unchanged.

---

## 2. Why it matters for platform engineering

Containers are the **unit of deployment** the rest of the platform is built around,
so this is foundational, not academic:

- **Everything downstream assumes it.** Kubernetes schedules containers, your CI
  builds images, your registry stores them, your policies govern them. Weak
  fundamentals here become mysterious failures three phases later.
- **Debugging requires the model.** "Why is my app PID 1 ignoring Ctrl-C?" "Why does
  the container see a different `/etc/hosts`?" "Why did it get OOMKilled at 512 MB?"
  Every one of these is a namespace or cgroup question.
- **Density and speed are the economic case.** Sharing the host kernel is what makes
  containers cheap to start and pack densely — the efficiency a platform resells to
  its teams.
- **Security is a kernel conversation.** Because the kernel is shared, the hardening
  in Module 02.5 (user namespaces, dropped capabilities, seccomp) is about
  tightening exactly the boundaries introduced here.

A platform engineer is the person teams escalate to when the abstraction leaks. You
can only be that person if you understand what's under it.

---

## 3. Mental model

```text
          ┌──────────────────────── a "container" ───────────────────────┐
          │                                                              │
  your process (PID 1 inside) ── sees ──▶ NAMESPACES  (what it can SEE)  │
          │                                 pid · net · mnt · uts · ipc · user
          │                                                              │
          │                     ── bounded by ──▶ CGROUPS (what it can USE)
          │                                 cpu · memory · io · pids     │
          │                                                              │
          │   root filesystem ◀── overlaid from ── OCI IMAGE LAYERS      │
          └──────────────────────────────────────────────────────────────┘
                                   all on the HOST's shared kernel
```

Three sentences to keep for a year:

- A container is **a process in namespaces, limited by cgroups, rooted in an image**.
- The kernel is **shared** — that's the power (efficiency) and the risk (isolation).
- A **tag moves, a digest doesn't** — identity in the image world is a content hash.

---

## 4. Minimal implementation

Before trusting `docker run`, create the key illusions **by hand** with `unshare`,
the tool that puts a new process into fresh namespaces. (Run on Linux/WSL2; `sudo`
is needed for PID and mount namespaces.)

```bash
# New UTS + PID + mount namespaces, with a fresh /proc so PID isolation is visible:
sudo unshare --fork --pid --mount-proc --uts /bin/bash

# Now you're "inside". Change the hostname — the host is unaffected (UTS namespace):
hostname container-by-hand

# List processes — you are PID 1 and cannot see the host's processes (PID namespace):
ps aux
#   PID USER  COMMAND
#     1 root  /bin/bash     <-- your shell is PID 1
#     N root  ps aux
```

You just built the core of a container with no Docker at all: a process that has its
own hostname and its own PID space. Add a network namespace (`--net`), a user
namespace (`--user`), a root filesystem (`chroot`/`pivot_root`), and a cgroup to cap
memory, and you have essentially reimplemented what `runc` does.

```bash
# Add a cgroup v2 memory cap (host shell), then put a shell into it:
sudo mkdir -p /sys/fs/cgroup/demo
echo 50M | sudo tee /sys/fs/cgroup/demo/memory.max
echo $$  | sudo tee /sys/fs/cgroup/demo/cgroup.procs   # this shell is now capped
```

The point is not to run containers this way — it is to see that `docker run` is a
friendly front end over `clone()` + namespace flags + cgroup files. Once you've done
it by hand, containers stop being magic. You'll do the full version in the lab.

---

## 5. Hands-on lab

You'll build a container-like environment **by hand** with namespaces and cgroups,
observe the isolation under `/proc`, then run the equivalent Docker container and
compare — proving to yourself that Docker is automating the same kernel features.

➡️ **[Start the lab: Build a container by hand](./lab/README.md)**

---

## 6. Production considerations

- **PID 1 matters.** The process you start is PID 1 inside the container and inherits
  init duties (reaping zombies, forwarding signals). A naive app as PID 1 may ignore
  `SIGTERM` and get `SIGKILL`ed on shutdown. Use a proper init (`--init`, `tini`) or
  handle signals explicitly.
- **Set cgroup limits deliberately.** No memory limit means a leaky container can take
  down a whole node. Always set requests/limits (Phase 3) — they are cgroup values.
- **The shared kernel is your blast radius.** A kernel vulnerability can cross the
  container boundary. Keep the host kernel patched; consider user namespaces and, for
  hostile multi-tenant workloads, VM-based sandboxes (Kata, gVisor, Firecracker).
- **Pin by digest in production.** Tags are mutable; `@sha256:…` is not. Promotion and
  rollback should reference digests so "what's running" is unambiguous.
- **Know your runtime.** In Kubernetes you're on `containerd`/CRI-O, not Docker. Use
  `crictl`/`nerdctl` to debug nodes; Docker-specific assumptions won't hold there.

## 7. Common mistakes

- **"A container is a lightweight VM."** — It has no guest kernel; it shares the
  host's. *Fix:* think "isolated process," which correctly predicts both the
  efficiency and the weaker isolation boundary.
- **Treating the container filesystem as persistent.** — The writable layer is
  thrown away on `rm`. *Fix:* use volumes for state (Module 02.4).
- **Ignoring PID 1 / signal handling.** — Slow or hung shutdowns and zombie
  processes. *Fix:* run an init or handle `SIGTERM`; don't launch your app via a
  shell that swallows signals.
- **Running with no resource limits.** — One container starves the node. *Fix:* set
  memory/CPU limits (cgroups) from the start.
- **Depending on mutable tags like `:latest`.** — "It worked yesterday" because the
  tag moved. *Fix:* reference immutable digests for anything you promote or roll back.

## 8. Assessment

**Knowledge checks**

1. In one sentence each, what do **namespaces** and **cgroups** each provide?
2. Name three namespace types and state what each isolates.
3. Give two concrete differences between a container and a virtual machine.
4. What is the difference between an image **tag** and an image **digest**, and why
   do platforms promote by digest?
5. Where does the **CRI** sit, and what does `runc` actually do?

**Concept exercise**

> Explain what a container is to a skeptical VM admin **without using the words
> "Docker," "image," or "Kubernetes."** Describe the mechanism, not the tool.

**Debugging exercise**

> A teammate says: "My container app logs 'starting' but `docker stop` takes 10
> seconds every time and then the process dies hard." Using the mental model from
> this module, what is almost certainly happening, and what are two fixes?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Namespaces isolate *what a process can see* (PIDs, network, mounts,
  hostname, IPC, users); cgroups limit *what a process can use* (CPU, memory, I/O).
- **Q2:** e.g. PID (process-ID space), NET (interfaces/ports/routes), MNT (mount
  table / root filesystem), UTS (hostname), IPC (shared memory/queues), USER
  (UID/GID mapping).
- **Q3:** A container shares the host kernel (no guest OS) vs a VM runs a full guest
  kernel on a hypervisor; containers are MB-sized and start in milliseconds vs
  GB-sized VMs that boot in seconds; the VM boundary is stronger isolation, the
  container boundary is lighter weight.
- **Q4:** A tag is a mutable human label that can be re-pointed; a digest is an
  immutable content hash of the manifest. Promoting by digest guarantees the exact
  same bits move from staging to prod, enabling trustworthy rollback.
- **Q5:** The CRI is the gRPC interface between the kubelet and a high-level runtime
  (`containerd`/CRI-O); `runc` is the low-level OCI runtime that calls `clone()`
  with namespace flags and configures cgroups to actually start the process.
- **Debugging:** The app is **PID 1** and isn't handling `SIGTERM`, so `docker stop`
  waits the grace period and then `SIGKILL`s it. Fixes: run with an init
  (`--init`/`tini`) so signals are forwarded, or make the app trap and handle
  `SIGTERM` for graceful shutdown.

</details>

---

## 9. Further reading

- Open Container Initiative — [Image Spec](https://github.com/opencontainers/image-spec)
  and [Runtime Spec](https://github.com/opencontainers/runtime-spec)
- Linux man pages — [`namespaces(7)`](https://man7.org/linux/man-pages/man7/namespaces.7.html),
  [`cgroups(7)`](https://man7.org/linux/man-pages/man7/cgroups.7.html),
  [`unshare(1)`](https://man7.org/linux/man-pages/man1/unshare.1.html)
- Kubernetes — [Container Runtime Interface (CRI)](https://kubernetes.io/docs/concepts/architecture/cri/)
  and [Don't Panic: Kubernetes and Docker](https://kubernetes.io/blog/2020/12/02/dont-panic-kubernetes-and-docker/)
- containerd — [architecture documentation](https://github.com/containerd/containerd/blob/main/docs/)
- Jérôme Petazzoni — ["Anatomy of a Container"](https://www.youtube.com/watch?v=sK5i-N34im8) (talk)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [02 · Containerization](../README.md)
· _Next:_ [02.2 — Dockerfile and Image Building →](../02-dockerfile-and-image-building/)
