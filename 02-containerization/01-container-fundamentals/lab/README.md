# Lab — Build a container by hand

> You'll assemble the core illusions of a container — isolated processes, hostname,
> and network, plus a resource limit — using only Linux `unshare` and cgroup files,
> with **no Docker**. Then you'll run the equivalent Docker container and compare,
> proving that `docker run` is automating exactly these kernel features.

**Estimated time:** ~45–60 minutes
**Type:** Discovery / build
**Deliverable:** Your own notes (or the provided [`worksheet.md`](./worksheet.md))
recording the namespace IDs and behaviour you observed by hand vs. under Docker.

## Objectives

- Create new PID, UTS, mount, and network namespaces by hand and observe the
  isolation they provide.
- Inspect namespaces via `/proc/<pid>/ns` and compare host vs. container.
- Use a cgroup to account/limit memory, and watch Docker enforce the same limit.
- Explain, from evidence, what Docker is doing for you.

## Prerequisites

- **Linux or WSL2** (a real Linux kernel). macOS/Windows native shells cannot do
  the namespace steps — use WSL2 on Windows, or a Linux VM.
- `sudo` access (PID and mount namespaces require privileges).
- Docker installed and working (`docker run --rm hello-world` succeeds). See
  [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md).
- `util-linux` (provides `unshare`, present by default on all Linux distros).

## Steps

1. **Record your host's namespaces (the baseline).**

   ```bash
   uname -a
   hostname
   ls -l /proc/self/ns
   ```

   Note the numbers in links like `pid:[4026531836]`. These identify your host
   namespaces. Anything with a *different* number later is isolated.

2. **Enter fresh UTS + PID + mount namespaces.**

   ```bash
   sudo unshare --fork --pid --mount-proc --uts /bin/bash
   ```

   `--uts` gives a private hostname, `--pid` a private process-ID space, `--fork`
   makes your shell the first process in it, and `--mount-proc` mounts a fresh
   `/proc` so process isolation is actually visible. You are now "inside".

3. **Prove UTS isolation — change the hostname.**

   ```bash
   hostname container-by-hand
   hostname                 # inside: container-by-hand
   ```

   Open a **second host terminal** and run `hostname` there — it is unchanged. You
   altered only this namespace.

4. **Prove PID isolation — you are PID 1.**

   ```bash
   ps -e
   #   PID TTY          TIME CMD
   #     1 pts/0    00:00:00 bash     <-- your shell is PID 1
   #     N pts/0    00:00:00 ps
   ```

   You cannot see the host's hundreds of processes. Inside this namespace, your
   shell is the init process. Compare its namespace IDs to the host's:

   ```bash
   ls -l /proc/self/ns        # pid/uts/mnt numbers differ from step 1
   ```

   Record the differences in your worksheet, then `exit` to leave this namespace.

5. **Prove NET isolation — an empty network stack.**

   ```bash
   sudo unshare --net /bin/bash
   ip addr                    # only 'lo', and it's DOWN — no eth0, no connectivity
   ping -c1 1.1.1.1 || echo "no network, as expected"
   exit
   ```

   A brand-new network namespace has nothing but a loopback device. Docker's job is
   to create a veth pair and wire this namespace to a bridge — you'll do that
   explicitly in Module 02.3.

6. **Limit memory with a cgroup (by hand).**

   cgroup v2 is a filesystem. Create a group and inspect its control files:

   ```bash
   sudo mkdir -p /sys/fs/cgroup/demo
   ls /sys/fs/cgroup/demo | grep -E 'memory.max|memory.current|cgroup.procs'
   echo 50M | sudo tee /sys/fs/cgroup/demo/memory.max
   cat /sys/fs/cgroup/demo/memory.current   # ~0 bytes; nothing is in the group yet
   ```

   > Note: if `memory.max` is missing, your parent cgroup hasn't delegated the
   > memory controller. Enable it with
   > `echo +memory | sudo tee /sys/fs/cgroup/cgroup.subtree_control` and retry. This
   > is exactly the plumbing Docker does for you.

   These files — `memory.max`, `cpu.max`, `cgroup.procs` — are the entire mechanism
   behind container resource limits.

7. **Watch Docker enforce the same limit (reliable OOM demo).**

   Forcing an out-of-memory kill by hand is fiddly; Docker does it reproducibly by
   writing the very `memory.max` file you just saw:

   ```bash
   docker run --rm -m 20m --name hog alpine \
     sh -c 'echo allocating...; tail /dev/zero'
   # The container is OOM-killed almost immediately.
   echo "exit code: $?"      # 137 = 128 + SIGKILL(9), the OOM kill
   ```

   Run it detached and inspect the flag the kernel set:

   ```bash
   docker run -d -m 20m --name hog alpine sh -c 'tail /dev/zero'; sleep 2
   docker inspect hog --format '{{.State.OOMKilled}} {{.State.ExitCode}}'
   # true 137
   docker rm -f hog
   ```

   `OOMKilled: true` is the cgroup `memory.max` doing its job — the same file,
   automated.

8. **Run the Docker equivalent of your hand-built container and compare.**

   ```bash
   docker run --rm -it --hostname container-by-docker alpine sh
   # inside the container:
   hostname            # container-by-docker  (UTS namespace)
   ps -e               # you are PID 1         (PID namespace)
   ip addr             # eth0 present & UP     (NET namespace, but wired up!)
   ls -l /proc/self/ns # all IDs differ from the host
   exit
   ```

   Fill in your worksheet: which isolations matched your by-hand result, and what
   did Docker add on top (a configured network, a root filesystem from an image)?

## Expected result

You can point to concrete evidence that a container is "a process in namespaces,
limited by cgroups":

- Hostname and PID changes that were invisible to the host (UTS, PID namespaces).
- An empty network namespace by hand vs. a wired-up `eth0` under Docker.
- `/proc/self/ns` numbers that differ from the host in both cases.
- An `OOMKilled: true` container proving cgroup memory limits are just files.

You should be able to complete this sentence from memory: *"Docker automated these
kernel features for me: ___, ___, ___."*

## Cleanup

> No cloud resources are created, but remove the cgroup and any containers.

```bash
# Remove the cgroup you created (must be empty; your capped processes have exited):
sudo rmdir /sys/fs/cgroup/demo 2>/dev/null || true

# Remove any leftover demo containers and the pulled images (optional):
docker rm -f hog 2>/dev/null || true
docker rmi alpine 2>/dev/null || true

# Exit any namespace shells you may still be in:
exit 2>/dev/null || true
```

## Reflection

- Which felt like the "aha": being PID 1, the empty network stack, or `OOMKilled`?
- Docker added a **network** and a **root filesystem** to the raw namespaces. Which
  module do you think covers each? (Hint: 02.3 and 02.2/02.4.)
- If a container shares the host kernel, what does that imply for security when you
  run untrusted code? (You'll answer this properly in Module 02.5.)

## Stretch goals (optional)

- Add a **user namespace**: `unshare --user --map-root-user /bin/bash`, then run
  `id` — you're "root" inside but mapped to your unprivileged UID on the host. Check
  with `cat /proc/self/uid_map`.
- Give your hand-built container a **real root filesystem**: download the Alpine
  minirootfs tarball, extract it, and `chroot` into it from inside your namespaces.
  You've now built ~90% of what `runc` does.
- Inspect a running Docker container's namespaces from the host with
  `sudo ls -l /proc/$(docker inspect -f '{{.State.Pid}}' <id>)/ns` and confirm the
  numbers match what you see inside.
