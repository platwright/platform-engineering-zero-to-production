# Lab — Persist a database across restarts

> You'll run PostgreSQL in a container two ways — without a volume (and watch its
> data vanish) and with a named volume (and watch it survive) — then explore bind
> mounts and tmpfs. This is the exact difference between a throwaway demo and a
> database you can trust.

**Estimated time:** ~30–45 minutes
**Type:** Build / discovery
**Deliverable:** Notes showing a row that was **lost** after recreate without a
volume and **survived** recreate with a named volume.

## Objectives

- Prove the container filesystem is ephemeral using a real database.
- Persist database state across container removal with a named volume.
- Inspect where a volume lives, and try bind-mount and tmpfs alternatives.

## Prerequisites

- Docker installed and working (`docker run --rm hello-world` succeeds). See
  [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md).
- Linux, macOS, or **WSL2** on Windows.
- No cost: everything runs locally.

> The password below (`devpassword`) is a **throwaway local dev value**, not a real
> credential. Never commit real secrets — you'll handle secrets properly in
> Module 02.5.

## Steps

1. **Run PostgreSQL with NO volume and write some data.**

   ```bash
   docker run -d --name pg-novol -e POSTGRES_PASSWORD=devpassword postgres:16
   sleep 5
   docker exec pg-novol psql -U postgres -c \
     "CREATE TABLE t(msg text); INSERT INTO t VALUES ('survive me');"
   docker exec pg-novol psql -U postgres -c "SELECT * FROM t;"
   # msg: survive me
   ```

2. **Destroy and recreate the container — watch the data vanish.**

   ```bash
   docker rm -f pg-novol
   docker run -d --name pg-novol -e POSTGRES_PASSWORD=devpassword postgres:16
   sleep 5
   docker exec pg-novol psql -U postgres -c "SELECT * FROM t;"
   # ERROR: relation "t" does not exist   <- data lived in the disposable layer
   docker rm -f pg-novol
   ```

   The table was written to the container's writable layer, which was deleted with
   the container. This is the ephemeral filesystem in action.

3. **Run PostgreSQL WITH a named volume and write data.**

   ```bash
   docker run -d --name pg-vol \
     --mount source=pgdata,target=/var/lib/postgresql/data \
     -e POSTGRES_PASSWORD=devpassword postgres:16
   sleep 5
   docker exec pg-vol psql -U postgres -c \
     "CREATE TABLE t(msg text); INSERT INTO t VALUES ('survive me');"
   ```

4. **Destroy and recreate against the same volume — watch the data survive.**

   ```bash
   docker rm -f pg-vol
   docker run -d --name pg-vol \
     --mount source=pgdata,target=/var/lib/postgresql/data \
     -e POSTGRES_PASSWORD=devpassword postgres:16
   sleep 5
   docker exec pg-vol psql -U postgres -c "SELECT * FROM t;"
   # msg: survive me   <- the volume outlived the container
   ```

5. **Inspect the volume.**

   ```bash
   docker volume inspect pgdata --format '{{.Mountpoint}}'
   # /var/lib/docker/volumes/pgdata/_data  (on Linux)
   ```

   The data lives in a Docker-managed directory, independent of any container.

6. **Try a bind mount (local-dev style) and discuss permissions.**

   ```bash
   mkdir -p "$PWD/pg-bind"
   docker run -d --name pg-bind \
     --mount type=bind,source="$PWD/pg-bind",target=/var/lib/postgresql/data \
     -e POSTGRES_PASSWORD=devpassword postgres:16
   sleep 5
   ls -la "$PWD/pg-bind" | head   # the DB files now appear in YOUR host directory
   ```

   A bind mount puts the data at a known host path — convenient for development, but
   it couples you to host paths and permissions (a frequent source of "permission
   denied" on other machines).

7. **Try tmpfs and prove it does not persist.**

   ```bash
   docker run --rm --mount type=tmpfs,target=/scratch alpine \
     sh -c 'echo secret > /scratch/x; cat /scratch/x'   # secret (in RAM only)
   # The tmpfs (and its contents) never touched disk and is gone now.
   ```

## Expected result

- **No volume:** the row is **lost** after recreate (step 2).
- **Named volume:** the row **survives** recreate (step 4).
- The named volume's data lives under `/var/lib/docker/volumes/...`.
- A bind mount surfaces the DB files in your host directory; tmpfs data never
  persists.

## Cleanup

> No cloud resources are created, but remove the containers, the volume, and the
> bind directory.

```bash
docker rm -f pg-novol pg-vol pg-bind 2>/dev/null || true
docker volume rm pgdata 2>/dev/null || true
rm -rf "$PWD/pg-bind"
docker rmi postgres:16 alpine 2>/dev/null || true
```

## Reflection

- Step 2 deleted a "database." In production, what process would have to exist so
  that recreating a container never loses data?
- The named volume still lives on **one host's disk**. What breaks when you move to a
  cluster of many machines (Phase 3)?
- Why might you deliberately choose **tmpfs** for some data?

## Stretch goals (optional)

- **Back up the volume** to a tarball and restore it into a fresh volume:

  ```bash
  docker run --rm --mount source=pgdata,target=/data \
    --mount type=bind,source="$PWD",target=/backup \
    alpine tar czf /backup/pgdata.tgz -C /data .
  ```

- Recreate the database from your backup tarball into a new volume and confirm the
  row is present — you've just performed a restore drill.
