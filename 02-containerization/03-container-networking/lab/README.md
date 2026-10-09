# Lab — Service discovery on a custom bridge

> You'll prove that the default bridge can't resolve names, then create a
> user-defined network where two containers find each other by **name**, publish a
> port to your host, and practise the troubleshooting commands you'll reach for
> every time a service "can't connect."

**Estimated time:** ~30–45 minutes
**Type:** Build / discovery
**Deliverable:** Evidence (command output in your notes) that name resolution
**failed** on the default bridge and **succeeded** on a user-defined bridge, plus a
short troubleshooting write-up.

## Objectives

- Observe that the default bridge provides connectivity but no DNS.
- Create a user-defined bridge and resolve a container by name.
- Publish a container port and reach it from the host.
- Inspect a container's networking from the inside.

## Prerequisites

- Docker installed and working (`docker run --rm hello-world` succeeds). See
  [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md).
- Linux or **WSL2** on Windows (the examples use Linux networking tools).
- No cost: everything runs locally.

## Steps

1. **Show the default bridge has no name resolution.**

   ```bash
   docker run -d --name db-default alpine sleep 600
   docker run --rm alpine sh -c "nslookup db-default || echo 'DNS FAILED (expected)'"
   ```

   Resolution fails: on the default bridge, containers only know each other by IP.
   This is the problem user-defined networks solve.

2. **Create a user-defined bridge and inspect it.**

   ```bash
   docker network create --driver bridge platform-net
   docker network inspect platform-net --format '{{(index .IPAM.Config 0).Subnet}}'
   # e.g. 172.19.0.0/16 — a private subnet Docker allocated for this network
   ```

3. **Run a service on the network and resolve it by name.**

   ```bash
   docker run -d --name svc-a --network platform-net nginx
   docker run --rm --network platform-net alpine \
     sh -c "nslookup svc-a && wget -qO- http://svc-a | head -n1"
   ```

   This time DNS resolves `svc-a` to its IP and the HTTP request returns nginx's
   welcome page. Name-based service discovery works because `platform-net` runs the
   embedded resolver at `127.0.0.11`.

4. **Prove the resolver is what's doing the work.**

   ```bash
   docker run --rm --network platform-net alpine cat /etc/resolv.conf
   # nameserver 127.0.0.11   <- Docker's embedded DNS
   ```

5. **Publish a port and reach the container from your host.**

   ```bash
   docker run -d --name web --network platform-net -p 8080:80 nginx
   curl -s http://localhost:8080 | head -n1
   # <!DOCTYPE html> ... — you reached container :80 via host :8080 (a DNAT rule)
   ```

6. **Troubleshoot from inside a container.**

   ```bash
   docker exec web sh -c "apk add --no-cache iproute2 >/dev/null 2>&1; \
     ip addr show eth0; ss -tlnp; getent hosts svc-a"
   ```

   You can see the container's `eth0` and IP, what's listening (`:80`), and that
   `svc-a` resolves — the three questions that answer most connectivity problems.

7. **(Optional) Contrast with host networking.**

   ```bash
   docker run -d --name web-host --network host nginx
   curl -s http://localhost:80 | head -n1   # nginx is directly on the host's :80
   docker rm -f web-host
   ```

   No `-p` was needed because the container shares the host's network namespace —
   fast, but with no isolation and a direct port conflict risk. (On Docker Desktop
   for macOS/Windows, host networking behaves differently; run this on Linux/WSL2.)

## Expected result

- Step 1 **fails** to resolve `db-default` (default bridge, no DNS).
- Step 3 **succeeds**: `svc-a` resolves and returns an HTTP response.
- Step 5: `curl localhost:8080` reaches the container through the published port.
- You can read a container's interfaces, listening ports, and DNS from the inside.

You've demonstrated the core rule: **user-defined networks give you DNS and
isolation; the default bridge does not.**

## Cleanup

> No cloud resources are created, but remove the containers and the network.

```bash
docker rm -f db-default svc-a web web-host 2>/dev/null || true
docker network rm platform-net 2>/dev/null || true
docker rmi nginx alpine 2>/dev/null || true
```

## Reflection

- Which failure was more surprising: no DNS on the default bridge, or needing `-p`
  to reach a container from the host?
- You hard-coded nothing — `svc-a` was reached by name. Why does that matter when a
  container's IP can change on every restart?
- How do you think Kubernetes scales this same idea (names → addresses) across many
  machines? (You'll find out in Phase 3.)

## Stretch goals (optional)

- Create a **second** network (`data-net`), attach a `db` container to it, and show
  that `web` on `platform-net` **cannot** reach it — then
  `docker network connect data-net web` and watch it start working. That's
  segmentation and controlled connectivity in action.
- Add a network **alias**: `docker run --network platform-net --network-alias api …`
  and resolve the container by both its name and `api`.
- Inspect the host iptables NAT rules Docker created: `sudo iptables -t nat -L -n`.
