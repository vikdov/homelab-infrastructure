# Ansible Role: restic

An advanced, production-ready Ansible role for configuring **append-only** restic backups to S3-compatible object storage (optimised for Cloudflare R2).

It provisions automated backups, integrity checks, and restore tests using deeply sandboxed systemd timers, and exports rich Prometheus metrics for monitoring.

## Features

- **Append-Only by Default (Locked Mode):** Designed to work with bucket-level lock rules (Object Lock) to ensure a compromised host cannot delete or overwrite its own backup history.
- **Automated Restore Tests:** A self-verifying canary (timestamp, nonce, checksum) is written before every backup. A monthly systemd timer restores and verifies this canary from the latest snapshot, proving the repository's decryption and retrieval path is healthy.
- **Rotating Integrity Checks:** Weekly read-only integrity checks rotate through fractions of the repository (`--read-data-subset`), ensuring the entire dataset is verified over a configurable cycle (default 12 weeks) without overloading the host.
- **Prometheus Monitoring:** Job exit codes, durations, and success timestamps are atomically written to the `node_exporter` textfile collector directory. A complete suite of alerting rules (`files/restic-alerts.rules.yml`) is provided.
- **Strict Sandboxing:** Systemd units are locked down with `ProtectSystem=strict`, `NoNewPrivileges=true`, `PrivateTmp=true`, and strict `CapabilityBoundingSet` limits.
- **Smart Concurrency:** All jobs (backup, check, restore, prune) share a host-wide lock via `flock` and queue elegantly without timing out.

## Requirements

- **Ansible:** 2.14+
- **Target OS:** Debian Trixie / Ubuntu Noble (and likely newer variants).
- **Metrics:** Prometheus Node Exporter with the textfile collector enabled (if `restic_metrics_enabled` is true).

## Operating Modes

This role supports two operating modes, controlled by the `restic_client_prune` boolean variable.

### 1. Locked Mode (Default: `restic_client_prune: false`)

Highly recommended for security. You must provision one bucket and one API token _per host_. The bucket should have an Object Lock / WORM rule configured (done outside this role) that prevents deletion of objects, except for the `locks/` prefix.

- The client only _adds_ data.
- No prune job is installed.
- You must run `restic forget --prune` manually from a secure admin workstation using an admin token.

### 2. Client-Prune Mode (`restic_client_prune: true`)

A trade-off for convenience. The role provisions an additional weekly `forget --prune` systemd timer.

- **Do NOT** enable bucket locks in this mode, as pruning will fail.
- A compromised host _can_ destroy its own backup history.
- Retention policies (`restic_keep_daily`, `restic_keep_weekly`, etc.) must be defined.

## Role Variables

### Required Variables

These must be defined. It is highly recommended to place secrets in `host_vars/<host>/vault.yml`.

| Variable                   | Description                                                        |
| -------------------------- | ------------------------------------------------------------------ |
| `restic_bucket`            | The name of the S3/R2 bucket.                                      |
| `restic_access_key_id`     | S3 Access Key ID. Scope this strictly to the host's bucket.        |
| `restic_secret_access_key` | S3 Secret Access Key.                                              |
| `restic_password`          | The repository encryption password. **Keep an offline copy!**      |
| `restic_paths`             | List of absolute paths to back up (e.g., `['/etc', '/var/data']`). |
| `restic_r2_account_id`     | Your Cloudflare account ID (if using R2 default endpoints).        |

### Optional / Configuration Variables

| Variable                 | Default                             | Description                                                                                             |
| ------------------------ | ----------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `restic_client_prune`    | `false`                             | Set to `true` to enable automated pruning from the client.                                              |
| `restic_bucket_prefix`   | `""`                                | Directory prefix inside the bucket. Useful if sharing a bucket between hosts (weaker isolation).        |
| `restic_pre_commands`    | `[]`                                | Shell commands to run _before_ the backup (e.g., database dumps). Runs as root before credentials load. |
| `restic_backup_rw_paths` | `['/var/backups']`                  | Paths the `pre_commands` need write access to under the strict sandbox.                                 |
| `restic_excludes`        | `[]`                                | List of patterns to exclude (written to an exclude file).                                               |
| `restic_snapshot_host`   | `{{ inventory_hostname }}`          | The hostname tagged on snapshots. Pin this before renaming a server.                                    |
| `restic_metrics_enabled` | `true`                              | Whether to write Prometheus textfile metrics.                                                           |
| `restic_metrics_dir`     | `/var/lib/prometheus/node-exporter` | Where to write the textfile metrics.                                                                    |

### Schedules and Retention

All schedules use systemd calendar formats.

- **Backup:** `restic_backup_schedule` (Default: `*-*-* 03:30:00`)
- **Check:** `restic_check_schedule` (Default: `Sun *-*-* 05:30:00`)
- **Restore Test:** `restic_restore_test_schedule` (Default: `*-*-01 06:30:00`)
- **Prune:** `restic_prune_schedule` (Default: `Sat *-*-* 04:30:00`)

_Retention (Only applies if `restic_client_prune: true`):_
`restic_keep_daily` (7), `restic_keep_weekly` (4), `restic_keep_monthly` (12), `restic_keep_yearly` (0).

### Custom S3 Providers (Non-Cloudflare R2)

By default, the role dynamically builds the Cloudflare R2 endpoint using your `restic_r2_account_id`. To use AWS S3, Backblaze B2, or MinIO, override the endpoint and region:

```yaml
restic_endpoint: "https://s3.eu-central-1.amazonaws.com"
restic_s3_region: "eu-central-1"
```

## Example Configuration

**`inventory/group_vars/restic_clients/main.yml`** (Shared config)

```yaml
restic_r2_account_id: "{{ vault_r2_account_id }}"
restic_r2_jurisdiction: "eu"
```

**`inventory/host_vars/web01/main.yml`** (Host-specific config)

```yaml
restic_bucket: web01-backup-bucket
restic_access_key_id: "{{ vault_restic_access_key_id }}"
restic_secret_access_key: "{{ vault_restic_secret_access_key }}"
restic_password: "{{ vault_restic_password }}"

restic_paths:
  - /etc
  - /srv/docker/data
```

## Monitoring & Alerts

The role includes a set of Prometheus alert rules in `files/restic-alerts.rules.yml`. These rules do not deploy automatically to the target nodes; you should load them into your Prometheus server. The rules detect failed runs, partial runs, and crucially, _stale or missing metrics_ (e.g., if a systemd timer dies silently).

## Sandboxing Notes (LXC Containers)

The systemd units utilize kernel namespaces to provide `ProtectSystem=strict` and `PrivateTmp=true`. If you are deploying this to an unprivileged LXC container, you must enable `nesting=1` in the container configuration, or set `restic_sandbox_enabled: false` in your host variables to prevent `226/NAMESPACE` unit failures.
