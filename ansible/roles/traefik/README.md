# traefik role

Traefik v3 as the edge proxy: wildcard certificate through the ACME DNS-01 challenge (Cloudflare),
one HTTPS router per entry in `traefik_services`, and an optional plain-HTTP loopback entrypoint
(`tunnel`, `127.0.0.1:8081`) for `cloudflared`.

Requires gathered facts (`architecture`, `date_time`); run `setup` first when the play uses
`gather_facts: false`. Tested on Debian 12.

## Required settings

| Variable               | Notes                                                              |
| ---------------------- | ------------------------------------------------------------------ |
| `traefik_version`      | Exact v3 release without `v`, e.g. `3.7.17`.                       |
| `traefik_domain`       | Real domain. `example.com/org/net` values are refused.             |
| `traefik_acme_email`   | Real address. `@example.*` is refused.                             |
| `traefik_cf_dns_token` | Cloudflare token (vault), see "Cloudflare token" below.            |

The role validates all inputs (and `traefik_services`) before touching the host. See
`defaults/main.yml` and `meta/argument_specs.yml` for every option.

## Migrating from the `edge_*` variables

| Old                              | New                                      |
| -------------------------------- | ---------------------------------------- |
| `edge_domain`                    | `traefik_domain`                         |
| `edge_acme_email`                | `traefik_acme_email`                     |
| `edge_acme_staging`              | `traefik_acme_staging`                   |
| `edge_secure_headers_enabled`    | `traefik_secure_headers_enabled`         |
| `edge_hsts_seconds`              | `traefik_hsts_seconds`                   |
| `edge_authelia_enabled`          | `traefik_authelia_enabled`               |
| `edge_authelia_url`              | `traefik_authelia_url`                   |
| `edge_authelia_authz_path`       | `traefik_authelia_authz_path`            |
| `edge_services`                  | `traefik_services`                       |

`traefik_arch` now defaults to `auto`. If the `cloudflared` role reads any `edge_*` variable,
rename it there too.

## Cloudflare token

The DNS-01 challenge needs `Zone:DNS:Edit` and `Zone:Zone:Read` (lego looks up the zone first).
Either give one token both permissions on the edge zone, or set `traefik_cf_zone_token` to a
second token with only `Zone:Zone:Read` and keep `traefik_cf_dns_token` at `Zone:DNS:Edit`.
Confirm with one real staging issuance (`journalctl -u traefik`).

## How requests are routed

- `traefik_services[].name` becomes `https://<name>.<traefik_domain>` on `websecure` (TLS 1.2+, SNI strict).
- `public: true` adds a second router for the same host on the `tunnel` entrypoint. Only those
  routers are reachable there. In the Cloudflare dashboard, point the tunnel's public hostname at
  `http://127.0.0.1:8081`.
- A public service must list the `authelia` middleware or set `allow_public_unauthenticated: true`.
  `rate-limit` and `in-flight` alone do not count as authentication.
- `secure-headers` (HSTS, nosniff, frame options, referrer policy) applies to every router unless
  `traefik_secure_headers_enabled: false` or the service sets `secure_headers: false`.
- Middlewares run in the order of the service's `middlewares` list, after `secure-headers`.
  Put `rate-limit` before `authelia`.
- `authelia` is a forward-auth middleware pointing at `traefik_authelia_url` + `traefik_authelia_authz_path`
  (default `/api/authz/forward-auth`, Authelia 4.38+). Do not put it on the `auth` portal itself.
  `websecure` trusts no proxy, so client-supplied `X-Forwarded-*` headers are overwritten before
  they reach Authelia; `tunnel` trusts loopback only.
- `rate-limit` / `in-flight` are opt-in (`traefik_rate_limit_enabled`, `traefik_inflight_enabled`).
  Behind the tunnel every request comes from 127.0.0.1, so there they limit per service, not per client.

## Operations

- **Upgrade / rollback:** change `traefik_version`. The release is checksum-verified, the unpacked
  binary must report that exact version before the symlink moves, and `traefik_keep_versions`
  (default 2) releases stay under `/opt/traefik`. A release already on disk is not downloaded again.
- **Staging to production:** set `traefik_acme_staging: false`. The role compares the CA recorded in
  `/var/lib/traefik/.acme-ca` with the configured one. On a change it stops Traefik, moves
  `acme.json` to `acme.json.<old-ca>.<timestamp>.bak`, restarts, and writes the marker last, so an
  interrupted run repeats the reset instead of skipping it. Hosts without a marker are classified by
  the account URI inside `acme.json`, so existing certificates are only reset when they really come
  from the other CA. `traefik_acme_backups_keep` (default 3) backups are retained. To undo, stop
  the service, copy the `.bak` back to `acme.json` (owner `traefik`, mode 0600), fix the flag, run again.
- **Access log:** JSON to journald, status 400-599 only by default (`traefik_access_log_status_codes`;
  empty list logs everything). Retention is journald's (`journald.conf`).
- **Metrics / health:** `traefik_metrics_address` defaults to `127.0.0.1:8082`. Bind it to a specific
  management-interface address to let Prometheus scrape; `0.0.0.0` is refused. Keep the firewall
  rule as a second layer.
- **No reload:** Traefik cannot reload its static configuration, so the unit has no `ExecReload`.
  Changes to the static config, unit or binary restart the service; `services.yml` is watched.
- **Hardening:** the unit is sandboxed (`ProtectSystem=strict`, syscall filter, ...). After changing
  it, run `systemd-analyze security traefik` and check `journalctl -u traefik`.

## Testing

```bash
cd ansible/roles/traefik
molecule test                    # fresh install, idempotence, routing, rendered config
molecule test -s lifecycle       # upgrade, staging->production switch, rollback, retention
molecule test -s validation      # every bad input is refused for the intended reason
```

Needs a Docker host that allows privileged systemd containers and outbound access to
`github.com`. The `lifecycle` scenario installs 3.7.17 and 3.7.19 and ends by contacting the Let's
Encrypt production directory once with a dummy account (the dummy token cannot complete an order).
