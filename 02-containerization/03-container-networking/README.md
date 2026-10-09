# Module 02.3 — Container Networking

> In Module 02.1 you saw that a fresh container gets its own **network namespace** —
> an empty stack with nothing but a down `lo` interface. Networking is how that empty
> namespace gets wired to other containers and the outside world. Master bridges,
> DNS, and port mapping, and "my service can't reach its database" turns from a
> mystery into a two-minute fix.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** [Module 02.1](../01-container-fundamentals/), Docker, and a Linux
shell (Windows: **WSL2**) for the by-hand `ip netns` example.

## Learning objectives

By the end of this module you will be able to:

- Explain how a container's empty network namespace gets connected with a **veth
  pair** and a **bridge**.
- Distinguish **bridge** (default vs user-defined), **host**, **overlay**, and
  **none** networks, and choose between them.
- Use **port mapping** to expose a container and explain the NAT rule it creates.
- Use Docker's **embedded DNS** for service discovery by container name.
- Troubleshoot connectivity with `ip`, `ss`, `getent`/`nslookup`, and `nsenter`.

---

## 1. Concept

### From an empty namespace to a connected one

A new network namespace has no path to anything. Docker connects it with a **veth
pair** — a virtual Ethernet "cable" with two ends. One end becomes `eth0` *inside*
the container; the other end stays on the host and is plugged into a **bridge**
(a virtual switch). By default that bridge is `docker0`.

```text
 container netns                 host
 ┌───────────────┐        ┌──────────────────────────┐
 │  eth0 ────────┼─veth───┤ vethXXXX ─┐               │
 │  172.17.0.2   │        │           ▼               │
 └───────────────┘        │        docker0 (bridge)   │
                          │        172.17.0.1         │
                          │           │ iptables NAT  │
                          │           ▼ (MASQUERADE)  │
                          │        eth0 → internet    │
                          └──────────────────────────┘
```

Containers on the same bridge can talk to each other directly (same subnet). To
reach the internet, the host **NATs** their traffic (an iptables `MASQUERADE` rule)
so replies find their way back. This is the default, and it's why a container can
`curl` the internet with no configuration but is not reachable *from* the outside
until you publish a port.

### The default bridge vs a user-defined bridge

This single distinction causes more confusion than anything else in container
networking:

- The **default bridge** (`docker0`, the network literally named `bridge`) gives
  containers connectivity but **no automatic name resolution**. Container A cannot
  reach container B by the name `b` — only by raw IP (or the deprecated `--link`).
- A **user-defined bridge** (one you create with `docker network create`) adds an
  **embedded DNS resolver**, so every container can reach every other by its
  **name** or network alias. It also isolates its members from containers on other
  networks.

> Rule of thumb: **never use the default bridge for multi-container apps.** Create a
> user-defined network so DNS and isolation work. This is the single most useful
> habit in this module.

### The network drivers

- **bridge** — the default; a private L2 network on one host. Great for most
  single-host, multi-container setups.
- **host** — `--network host` drops the network namespace entirely; the container
  shares the host's stack. Maximum performance (no NAT, no veth), but **no
  isolation**, port conflicts with the host, and it's Linux-specific. Use only when
  you truly need it (e.g. a high-throughput proxy).
- **overlay** — a multi-host network built on **VXLAN** tunnels, so containers on
  different machines share one virtual network. This is what Swarm uses and
  conceptually what a Kubernetes **CNI** plugin provides cluster-wide.
- **none** — `--network none`; only `lo`. Fully isolated; you wire networking
  yourself (or deliberately deny it).

### Port mapping: publishing a container

A container's `:80` lives inside its own namespace — it is **not** the host's `:80`.
To reach it from outside the host you **publish** it:

```text
 docker run -p 8080:80 nginx
               │    │
               │    └── container port (inside the netns)
               └─────── host port (what you curl)

 A DNAT rule rewrites  host:8080  →  172.17.0.2:80
```

`-p HOST:CONTAINER` installs a destination-NAT (DNAT) rule. Mixing up the order is a
classic bug. If you only need local access, bind to loopback:
`-p 127.0.0.1:8080:80` so the port isn't exposed on every host interface.

### Container DNS

On a user-defined network, each container's `/etc/resolv.conf` points at Docker's
**embedded resolver at `127.0.0.11`**. That resolver answers queries for container
names and aliases on the same network, and forwards everything else (like
`example.com`) to the host's upstream DNS. Service discovery "by name" is just this
resolver returning the right container IP — the same idea Kubernetes Services and
cluster DNS implement at scale.

### Troubleshooting toolkit

- `ip addr` / `ip route` — interfaces and routes inside a container.
- `ss -tlnp` — which ports are actually listening.
- `getent hosts NAME` or `nslookup NAME` — is DNS resolving?
- `cat /etc/resolv.conf` — is the resolver `127.0.0.11`?
- `nsenter` / `docker exec` — run tools *inside* the container's namespaces.

---

## 2. Why it matters for platform engineering

Networking is where most "works on my laptop" surprises and production outages live:

- **Service-to-service communication is the backbone of every microservice
  platform.** The platform decides the network model teams build on; get it wrong
  and every team re-invents service discovery.
- **The top developer complaint is "X can't reach Y."** Nine times out of ten it's
  the default bridge (no DNS), the wrong network, or an unpublished port. Knowing
  the model makes you the person who fixes it in minutes.
- **Segmentation is security.** Putting the database tier on a separate network from
  the public tier limits blast radius — the container-level precursor to Kubernetes
  NetworkPolicy and zero-trust networking (Phase 13/14).
- **Performance is a real trade-off.** Bridge NAT adds overhead; host networking
  removes it but sacrifices isolation. Platforms make that choice deliberately, per
  workload.

The mental model here (namespaces, veth, a virtual switch, a DNS resolver, NAT for
publishing) transfers almost directly to Kubernetes networking later.

## 3. Mental model

```text
                 one host
  ┌───────────────────────────────────────────────┐
  │   user-defined bridge "app-net" (has DNS!)     │
  │   ┌──────────┐   name:svc-a      ┌──────────┐  │
  │   │  svc-a   │◀───────────────── │  svc-b   │  │
  │   │ 10.0.0.2 │  "connect to      │ 10.0.0.3 │  │
  │   └────┬─────┘   http://svc-a"   └────┬─────┘  │
  │        │  both ask resolver 127.0.0.11│        │
  │        └───────────────┬───────────────┘        │
  │               publish: -p 8080:80               │
  └───────────────────────┼─────────────────────────┘
                          ▼
                  host:8080  ── curl from your laptop
```

Three things to remember:

- A container starts with an **empty** network stack; a veth pair + bridge connect
  it. Nothing is reachable until something wires it up.
- **User-defined network ⇒ DNS by name + isolation.** Default bridge ⇒ neither.
- **Inside is not outside.** Container ports are private until you **publish** them.

## 4. Minimal implementation

Before `docker network`, build the core of container networking **by hand** with
`ip netns`. This is exactly what Docker automates. (Linux/WSL2, `sudo`.)

```bash
# 1. Create a network namespace (Docker makes one per container):
sudo ip netns add demo

# 2. Create a veth "cable" and move one end into the namespace:
sudo ip link add veth-host type veth peer name veth-c
sudo ip link set veth-c netns demo

# 3. Address both ends and bring them up:
sudo ip addr add 10.10.0.1/24 dev veth-host
sudo ip link set veth-host up
sudo ip netns exec demo ip addr add 10.10.0.2/24 dev veth-c
sudo ip netns exec demo ip link set veth-c up
sudo ip netns exec demo ip link set lo up

# 4. Traffic now crosses the "cable":
sudo ip netns exec demo ping -c1 10.10.0.1
# 64 bytes from 10.10.0.1: icmp_seq=1 ttl=64 time=0.05 ms
```

You just built a point-to-point link between a namespace and the host. Docker does
this for every container, then attaches the host end to `docker0` (so many
containers share one switch), adds NAT for outbound traffic, and runs a DNS resolver
for names. Clean up with `sudo ip netns del demo`.

The lesson: `docker network` is a friendly automation over veth pairs, a bridge,
iptables NAT, and a resolver — all of which you can now create yourself.

## 5. Hands-on lab

You'll prove the default-bridge-has-no-DNS problem first-hand, then create a
user-defined bridge, watch two containers find each other **by name**, publish a
port to your host, and practise the troubleshooting commands on a live container.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **Default to user-defined networks.** You get DNS, isolation, and a stable model.
  The default bridge is for throwaway one-offs only.
- **Segment by trust tier.** Separate public, app, and data networks so a
  compromised front end can't reach the database directly. This is the precursor to
  NetworkPolicy.
- **Publish the minimum.** Every published port is attack surface. Bind local-only
  services to `127.0.0.1`, and never expose a database to `0.0.0.0` by habit.
- **Avoid host networking except for a reason.** It removes isolation and causes
  port conflicts; it also doesn't exist the same way on Docker Desktop (macOS/Win).
- **Mind overlay MTU.** VXLAN adds ~50 bytes of header; leaving MTU at 1500 causes
  fragmentation and mysterious hangs on large payloads. Set the MTU explicitly.
- **Don't hard-code IPs.** Container IPs are ephemeral. Use names/DNS (and, later,
  Kubernetes Services) so endpoints survive restarts and rescheduling.

## 7. Common mistakes

- **Using the default bridge and expecting name resolution.** — Containers can only
  reach each other by IP there, so `connect to svc-db` fails. *Fix:* create a
  user-defined network (`docker network create`) and attach both containers.
- **Confusing host and container ports in `-p`.** — `-p 80:8080` when you meant
  `-p 8080:80` publishes the wrong thing. *Fix:* remember `-p HOST:CONTAINER`.
- **Forgetting to publish a port at all.** — The service works container-to-container
  but "isn't reachable from my browser." *Fix:* publish it (`-p`) to reach it from
  the host/outside.
- **Hard-coding container IP addresses.** — They change on every recreate. *Fix:*
  use container names / DNS aliases.
- **Reaching for `--network host` to "make it work."** — You lose isolation and hit
  port conflicts. *Fix:* use a bridge network and publish only what you need.
- **Binding everything to `0.0.0.0`.** — Exposes internal services on every
  interface. *Fix:* bind local-only ports to `127.0.0.1`.

## 8. Assessment

**Knowledge checks**

1. Why do two containers on the **default** bridge fail to resolve each other by
   name, while two on a **user-defined** bridge succeed?
2. What does `-p 8080:80` actually create, and which number is the **host** port?
3. What is the IP of Docker's embedded DNS resolver, and where is it referenced?
4. When would you choose **host** networking, and what do you give up?
5. A container can `ping 1.1.1.1` but `ping svc-db` says "bad address." What's broken?

**Concept exercise**

> Explain how one container reaches another **by name** without using the words
> "Docker" or "DNS." Describe the mechanism: what does each container consult, and
> what does it get back?

**Debugging exercise**

> `svc-web` logs `could not resolve host: svc-db`. Both containers are running.
> Walk through your diagnosis step by step — which commands do you run, and what
> would each result tell you?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** The default bridge has no embedded DNS for container names (only legacy
  `--link`); a user-defined bridge runs a resolver at `127.0.0.11` that maps
  container names/aliases to IPs on that network.
- **Q2:** It installs a DNAT rule mapping `host:8080` → `container:80`. `8080` is
  the **host** port (first number: `HOST:CONTAINER`).
- **Q3:** `127.0.0.11`, referenced in each container's `/etc/resolv.conf` on a
  user-defined network.
- **Q4:** Host networking suits latency/throughput-sensitive workloads that can't
  afford NAT/veth overhead; you give up network isolation, get host port conflicts,
  and lose portability across platforms.
- **Q5:** Name resolution. The route to the internet works (so connectivity/NAT is
  fine), but the name `svc-db` isn't resolving — likely the containers aren't on the
  same user-defined network (or you're on the default bridge). Put both on one
  user-defined network.
- **Debugging:** Confirm both are on the same user-defined network
  (`docker network inspect`); from `svc-web` run `cat /etc/resolv.conf` (expect
  `127.0.0.11`), `getent hosts svc-db` / `nslookup svc-db`, check the exact name vs
  alias, and verify `svc-db` is actually listening with `ss -tlnp`. Most often the
  two aren't sharing a user-defined network.

</details>

## 9. Further reading

- Docker — [Networking overview](https://docs.docker.com/network/) and
  [Bridge network driver](https://docs.docker.com/network/drivers/bridge/)
- Docker — [Container DNS and embedded resolver](https://docs.docker.com/network/#dns-services)
- Linux man pages — [`ip-netns(8)`](https://man7.org/linux/man-pages/man8/ip-netns.8.html)
  and [`veth(4)`](https://man7.org/linux/man-pages/man4/veth.4.html)
- CNI — [the Container Network Interface spec](https://www.cni.dev/)
- Kubernetes — [Cluster networking concepts](https://kubernetes.io/docs/concepts/cluster-administration/networking/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [02.2 — Dockerfile and Image Building](../02-dockerfile-and-image-building/)
· _Next:_ [02.4 — Container Storage →](../04-container-storage/)
