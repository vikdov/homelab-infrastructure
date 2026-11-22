# apps role

Deploys **Nextcloud** and **Immich** as separate Docker Compose projects on a Debian host, behind an external HTTPS-terminating reverse proxy. An optional host-side `DOCKER-USER` firewall restricts connections to the published IPv4 ports, and a backup helper dumps databases for a separate restic workflow.

## Requirements

- Debian host with privileges to manage Docker, systemd, files, and iptables.
- The `docker` role runs before `apps` (see `ansible/playbooks/apps.yml`) and provides Docker Engine plus Compose **v2.24+** (required for `env_file` `required: false`).
- Collection `community.docker` **>= 3.8.0** (`docker_compose_v2` `wait` and `wait_timeout`).
- For the bundled firewall: Docker's **iptables firewall backend** and a `DOCKER-USER` chain (IPv4 only; native nftables Docker firewalling and IPv6 ingress rules are not supported).
- An edge reverse proxy terminating HTTPS, forwarding client headers, enforcing upload limits, and routing to `apps_bind`.
- Optional: a `restic` role invoking `restic_pre_commands` and `restic_post_commands` from `host_vars`.

## Configuration

See `ansible/inventory/host_vars/apps/main.yml.example` and `vault.yml.example`.

| Variable                   | Purpose                                                                                                                                  |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `apps_domain`              | Base domain (valid DNS hostname); Nextcloud is served as `cloud.<domain>`.                                                               |
| `apps_edge_proxies`        | Nonempty list of IPv4 addresses **as seen by the apps**; trusted by Nextcloud (`TRUSTED_PROXIES`) and Immich (`IMMICH_TRUSTED_PROXIES`). |
| `apps_bind`                | Non-wildcard, non-loopback IPv4 address on which Docker publishes host ports; defaults to `ansible_host`.                                |
| `nextcloud_version`        | Exact `X.Y.Z` version, required when `nextcloud_enabled: true`.                                                                          |
| `nextcloud_admin_user`     | Initial administrator user (letters, digits, `_ . @ -`); only used on the first install.                                                 |
| `nextcloud_admin_password` | Initial administrator password, required when Nextcloud is enabled; store in Ansible Vault without single quotes.                        |
| `immich_version`           | Exact `vX.Y.Z` version, required when `immich_enabled: true`.                                                                            |
| `immich_postgres_image`    | Full database image reference copied from the **matching Immich release's** official Compose file; required when Immich is enabled.      |

Key defaults:

- `apps_data_root: /srv/apps` — Nextcloud app code, databases, generated secrets, and SQL dumps.
- `apps_media_root: "{{ apps_data_root }}"` — Nextcloud user data and Immich media. When separate from `apps_data_root`, it **must be the mountpoint itself**, defined in `/etc/fstab` or a systemd `.mount` unit.
- `apps_timezone: "{{ bootstrap_timezone | default('UTC') }}"` — Container timezone; inherits `bootstrap_timezone` from host/group vars when defined.
- `nextcloud_port: 8080`, `immich_port: 2283` — IPv4 host ports published on `apps_bind`.
- `apps_firewall_enabled: true` — manages `apps-firewall.service` and the `APPS-INGRESS` chain.
- `apps_firewall_allowed_sources` — defaults to `(apps_edge_proxies + [apps_bind]) | unique`; every entry must be an IPv4 address.
- `nextcloud_enabled: true`, `immich_enabled: true` — control whether deployment tasks run; **setting either to `false` does not stop existing containers**. Backup dumps are still taken for a disabled app whose database container is running (see Backups and recovery).
- `apps_backup_nextcloud_maintenance: false` — toggles Nextcloud maintenance mode during backups.
- `apps_log_max_size: 10m`, `apps_log_max_file: "3"` — per-container `json-file` log rotation.
- `*_mem_limit` — **hard cgroup caps**; a container exceeding its cap is OOM-killed, not throttled. See Operations.

The stacks live under `/opt/apps/nextcloud` and `/opt/apps/immich`. Database passwords are generated once under `<apps_data_root>/secrets` (`0700`, root-owned) and reused across runs.

## Deploying and tags

Run the first deployment without tag filtering (or with `--tags docker,apps`) so Docker is provisioned and `firewall.yml` applies rules before either stack starts:

```sh
ansible-playbook ansible/playbooks/apps.yml
```

Available tags: `apps` (playbook level), `nextcloud`, `immich`, and `firewall`. Playbook `pre_tasks`, role assertions, mount validation, and secret generation are tagged `always`. Running `--tags nextcloud` or `--tags immich` alone skips `firewall.yml`; use selective tags only after initial firewall deployment.

## Firewall

When `apps_firewall_enabled: true`, `/usr/local/sbin/apps-firewall.sh` atomically replaces the `APPS-INGRESS` chain (jumped from `DOCKER-USER`) to permit `apps_firewall_allowed_sources` and drop other DNATed TCP traffic targeting `apps_bind` on `nextcloud_port` and `immich_port`. Both ports remain protected even if an app is disabled, because its containers remain running. Connections originating on the host itself (such as the role's health checks) never traverse `FORWARD`/`DOCKER-USER` and are not affected by these rules.

Verify live rules:

```sh
systemctl status apps-firewall.service
iptables -S DOCKER-USER
iptables -S APPS-INGRESS
```

Limitations and operational notes:

- **Boot window:** Docker can restore published ports a few seconds before `apps-firewall.service` finishes starting. Restrict ingress to `apps_bind` at the network/hypervisor perimeter as well.
- **Destination vs. source isolation:** Binding to `apps_bind` restricts the destination IPv4 address; routed traffic from adjacent networks still reaches `DOCKER-USER` unless filtered upstream.
- **Disabling the firewall:** Setting `apps_firewall_enabled: false` skips firewall tasks without removing an active unit or chain. After stopping the stacks or putting upstream ACLs in place, tear down live rules manually:

```sh
systemctl disable --now apps-firewall.service
iptables -D DOCKER-USER -m conntrack --ctdir ORIGINAL -j APPS-INGRESS
iptables -F APPS-INGRESS && iptables -X APPS-INGRESS
```

## Upgrades

- Review the release notes for Nextcloud or Immich (including required database/extension versions).
- Run a full backup (`/opt/apps/backup.sh pre`, run restic, then `/opt/apps/backup.sh post`).
- Bump `nextcloud_version` one major version at a time, or update `immich_version` together with `immich_postgres_image` from that release's Compose file.
- Re-run `ansible-playbook ansible/playbooks/apps.yml --tags nextcloud` (or `immich`, or untagged).
- Verify external HTTPS access, container health, Nextcloud's admin overview, and Immich background jobs.
- Check for OOM kills and restart loops (see Operations).

PostgreSQL major upgrades require a dump and restore, not a tag bump. Official PostgreSQL 18+ images also change the default `PGDATA` directory layout under `/var/lib/postgresql`, so review the `.../nextcloud/db` volume mount before moving past PostgreSQL 17. Images such as `postgres:17-alpine`, `redis:7-alpine`, and `valkey:8-bookworm` are moving tags; pin `@sha256:<digest>` in `host_vars` for strict reproducibility.

## Backups and recovery

`/opt/apps/backup.sh` manages database dumps in `<apps_data_root>/backup`:

- `backup.sh pre` writes `nextcloud.sql.gz` (`pg_dump`) and `immich.sql.gz` (`pg_dumpall --clean --if-exists`), validating each gzip archive before replacing the previous dump. For an **enabled** app, a missing or stopped database container fails the backup. For a **disabled** app, the dump is taken only if its database container is still running; otherwise it is skipped.
- `backup.sh post` disables Nextcloud maintenance mode when `apps_backup_nextcloud_maintenance: true`.

In `host_vars/apps/main.yml.example`, live database directories are excluded from restic only while the corresponding app is enabled, making the SQL dumps the primary database backup. When an app is disabled, its database directory is included in the snapshot: this is a valid cold copy if its containers are stopped, but an inconsistent file copy if they are still running. In that case the SQL dump is authoritative.

- **Maintenance mode:** Keep `apps_backup_nextcloud_maintenance: false` unless your restic orchestration guarantees `backup.sh post` runs even when the backup fails. If an interrupted backup leaves maintenance mode active, run `/opt/apps/backup.sh post`.
- **Restore outline:**
  1. Restore the matching restic snapshot (`apps_data_root`, `apps_media_root`, `/opt/apps`) to the target host so `<apps_data_root>/secrets`, Compose files, and media/app directories are in place before any container initializes. If the snapshot contains a database directory (`nextcloud/db` or `immich-db`, which happens for a disabled app), remove it so the database starts from an empty directory in step 3.
  2. Provision Docker without starting application stacks by running `ansible-playbook ansible/playbooks/apps.yml --tags docker` (the `always`-tagged secret task preserves the restored secret files).
  3. Start only the database container (`db` or `database`) against an empty data directory, keeping app/worker containers stopped:
     `docker compose -f /opt/apps/nextcloud/compose.yaml up -d db` and/or `docker compose -f /opt/apps/immich/compose.yaml up -d database`.
  4. Restore Nextcloud with `gunzip -c <apps_data_root>/backup/nextcloud.sql.gz | docker compose -f /opt/apps/nextcloud/compose.yaml exec -T db psql -v ON_ERROR_STOP=1 -U nextcloud nextcloud`. For Immich, `apps-backup.sh` produces a cluster dump using Immich's official `pg_dumpall --clean --if-exists` format; restore it into a fresh PostgreSQL cluster:
     `gunzip -c <apps_data_root>/backup/immich.sql.gz | docker compose -f /opt/apps/immich/compose.yaml exec -T database psql --dbname=postgres --username=immich`
     (Note: `DROP ROLE immich` in `pg_dumpall --clean` emits an expected error when connected as `immich`, so do not pass `-v ON_ERROR_STOP=1`; verify the exact restore command and any `search_path` or vector-extension steps against the official docs for your pinned `immich_version` on a disposable host, and re-verify whenever `immich_postgres_image` changes.)
  5. **Immich excluded folders (verify for your pinned version):** the example excludes `<apps_media_root>/immich/thumbs` and `<apps_media_root>/immich/encoded-video` from restic. Some Immich versions check for a `.immich` marker file in every media folder at startup and refuse to start without it. During your disposable-host rehearsal, confirm whether this applies; if it does, recreate the folders and markers before starting Immich, then regenerate thumbnails and encoded videos with Immich's missing-asset jobs:
     `install -d <apps_media_root>/immich/thumbs <apps_media_root>/immich/encoded-video && touch <apps_media_root>/immich/thumbs/.immich <apps_media_root>/immich/encoded-video/.immich`
  6. Run the full playbook (`ansible-playbook ansible/playbooks/apps.yml`) to apply firewall rules, start all remaining containers, and run health checks, then verify logins, files, media, and background jobs.

## Moving the media library

Stop application writes/containers, mount the new disk, move existing data from `nextcloud/data` and `immich` while preserving ownership (`33:33` for Nextcloud) and permissions, set `apps_media_root` to the mountpoint, and re-run the playbook. The mount must be defined in `/etc/fstab` or a systemd `.mount` unit: the role verifies the mountpoint and installs `/etc/systemd/system/docker.service.d/apps-media-mount.conf` (`RequiresMountsFor=`) so Docker will not start—and containers cannot write to the root filesystem—if the disk fails to mount at boot, but that protection only works when systemd knows the mount. Verify with:

```sh
systemctl status "$(systemd-escape -p --suffix=mount <apps_media_root>)"
```

Setting `apps_media_root` back to `apps_data_root` removes the drop-in.

## Operations

```sh
docker compose -f /opt/apps/nextcloud/compose.yaml ps
docker compose -f /opt/apps/immich/compose.yaml ps
systemctl status apps-firewall.service
iptables -S APPS-INGRESS
```

Check for OOM kills and restart loops (also after upgrades and large imports):

```sh
docker inspect --format '{{.Name}} oom={{.State.OOMKilled}} restarts={{.RestartCount}}' \
  $(docker compose -f /opt/apps/nextcloud/compose.yaml ps -aq) \
  $(docker compose -f /opt/apps/immich/compose.yaml ps -aq)
```

Notes:

- `APACHE_BODY_LIMIT=0` is set in `nextcloud.env` so upload sizes are governed by `nextcloud_php_upload_limit` and the edge reverse proxy rather than Apache's default 1 GiB limit.
- `nextcloud-admin.env` is rendered only when `config/config.php` does not yet exist and is deleted once `status.php` reports the instance as installed. After a fresh install the admin variables disappear from the app container's environment, so the **next run recreates the app container once**. Subsequent password changes require `occ user:resetpassword`.
- `NEXTCLOUD_TRUSTED_DOMAINS` applies on initial installation only; subsequent domain changes require `occ config:system:set trusted_domains`.
- All `*_mem_limit` values are **hard caps** (OOM-kill, not throttling). Defaults are sized for typical libraries; observe real usage with `docker stats` and the OOM check above, especially for `immich_server_mem_limit` (thumbnails, transcoding, metadata extraction), `immich_ml_mem_limit` (face/smart-search models), `immich_db_mem_limit` (vector indexing), `nextcloud_mem_limit`, and `nextcloud_db_mem_limit`, and adjust in `host_vars` if needed.
- `nextcloud_cron_mem_limit` must stay above `nextcloud_php_memory_limit`: `nextcloud.env` (including `PHP_MEMORY_LIMIT`) is shared by the app and cron containers, so a cron cap below the PHP limit turns heavy background jobs into OOM kills.
- Check mode is not supported on a never-deployed host because database secret files and the firewall unit do not exist yet.
