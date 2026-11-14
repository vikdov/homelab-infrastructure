# cloudflared role

Runs a remotely managed Cloudflare Tunnel from the Cloudflare apt repository. Ingress rules live in
the Zero Trust dashboard; point the public hostnames at Traefik's loopback entrypoint
`http://127.0.0.1:8081` (see the traefik role).

## State is explicit

`cloudflared_state: present` (default) installs and runs the tunnel and **fails** if anything
required is missing. `cloudflared_state: absent` stops it and removes the unit, env file, token,
apt source, pin, key, package and service user. It never skips silently. Removing the client does
not revoke the token: rotate or delete the tunnel in the dashboard too.

## Required settings (present)

| Variable                 | Notes                                                                                                                                                                  |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cloudflared_token`      | Tunnel token (vault). No whitespace.                                                                                                                                   |
| `cloudflared_version`    | Exact apt version, e.g. `2026.10.7`. Pinned with apt preferences so `apt upgrade` cannot move it. Check candidates with `apt-cache policy cloudflared`.                |
| `cloudflared_key_sha256` | sha256 of the signing key: `curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \| sha256sum`. The run fails if Cloudflare rotates the key, so re-check it then. |

## Optional settings

| Variable                       | Default                               | Notes                                                                                     |
| ------------------------------ | ------------------------------------- | ----------------------------------------------------------------------------------------- |
| `cloudflared_metrics`          | `127.0.0.1:20241`                     | Valid IPv4:port; `0.0.0.0` is rejected. Also used by the `/ready` check.                  |
| `cloudflared_protocol`         | `auto`                                | `auto` (QUIC, falls back to HTTP/2), `quic`, `http2`. Use `http2` if UDP 7844 is blocked. |
| `cloudflared_gomemlimit`       | `128MiB`                              | Soft Go heap target.                                                                      |
| `cloudflared_memory_max`       | `256M`                                | Hard cgroup ceiling (systemd `MemoryMax`).                                                |
| `cloudflared_egress_check`     | `true`                                | Preflight TCP probe of the edge on 7844 before anything is changed.                       |
| `cloudflared_egress_hosts`     | `region1/2.v2.argotunnel.com`         | Hosts probed by the preflight.                                                            |
| `cloudflared_apt_lock_timeout` | `bootstrap_apt_lock_timeout` or `300` | Seconds to wait for the dpkg lock.                                                        |

## Network requirements

The host needs **outbound** access, no inbound ports:

- `7844/udp` (QUIC) and `7844/tcp` (HTTP/2 fallback) to `region1.v2.argotunnel.com` and
  `region2.v2.argotunnel.com` (Cloudflare publishes the current list in its firewall docs).
- `443/tcp` to `pkg.cloudflare.com` for the apt repository.
- DNS and a working clock.

Open them in the guest, Proxmox and any upstream firewall. The preflight only proves TCP; QUIC over
UDP cannot be probed this way. If UDP is blocked, the tunnel still works via HTTP/2, or set
`cloudflared_protocol: http2` to skip the failed QUIC attempts.

## Secrets

The token is written to `/etc/cloudflared/token` (root, 0600, directory 0700) and given to the
service with `LoadCredential=`. It is not in the process environment, not visible in
`/proc/<pid>/environ` and not in `systemctl show`. `/etc/cloudflared.env` holds no secrets. All
tasks that handle the token use `no_log`.

## Operations

- **Upgrade / rollback:** change `cloudflared_version`; the role restarts the service and checks
  `cloudflared --version` afterwards.
- **Start semantics:** the unit is `Type=notify`, so systemd reports the start as successful only
  once the tunnel is connected. The role then also polls `/ready`. If anything fails, the last 40
  journal lines are printed with the error.
- **Check mode:** package, file and unit changes are previewed; the start and verification steps are
  skipped because they need a real service.
- **Metrics:** bind `cloudflared_metrics` to the management interface only to let Prometheus scrape.
  The listener is unauthenticated and also serves debug endpoints, so the firewall rule for that
  address is the only protection. Never expose it beyond the management network.
- **Hardening:** the unit drops all capabilities, denies W+X memory, hides other processes and is
  sandboxed. After changing it, run `systemd-analyze security cloudflared` and check
  `journalctl -u cloudflared`. A harmless ICMP/ping-group warning in the logs is expected because
  the capability set is empty.

## Memory

`GOMEMLIMIT` is a soft target; `MemoryMax` is the backstop. Both are conservative starting points,
not tuned values. After go-live, watch `process_resident_memory_bytes` and
`go_memstats_heap_inuse_bytes` on the metrics endpoint for a few days under real load, then set
`cloudflared_gomemlimit` to roughly 75% of the observed peak plus headroom and keep
`cloudflared_memory_max` about twice that. If the service is OOM-killed (`journalctl -k`), raise both.

## High availability

One connector on one VM is a single point of failure. For HA run the role on at least two hosts in
the `edge` group with the **same** token and, ideally, different hypervisors. Cloudflare balances
across connectors of one tunnel and keeps serving through the healthy one. The playbook uses
`serial: 1` and `max_fail_percentage: 0` so a bad change stops after the first host. Give each host
its own `cloudflared_metrics` address if it listens on a management IP.

## Ingress rules live outside git

Remotely managed tunnels keep their ingress in the dashboard, so they are not reviewed or rolled
back with this repository and can drift. Options, in increasing strength:

1. Record the current hostnames and services in the repo (see `edge_services` in host_vars) and
   compare them after dashboard changes.
2. Manage the tunnel configuration with Terraform (`cloudflare_zero_trust_tunnel_cloudflared_config`)
   so changes go through review and can be rolled back. The token stays the same.
3. Restrict who may edit the account (dashboard roles, audit log alerts).

## Exposing services publicly

The role only provides the transport. For anything routed through the tunnel:

- Authenticate before the origin: Authelia middleware in Traefik and/or Cloudflare Access in front of
  the hostname. Consider WAF and rate-limiting rules for public hostnames.
- The Traefik `tunnel` entrypoint (127.0.0.1:8081) must trust forwarded headers (`CF-Connecting-IP`,
  `X-Forwarded-*`) **only from 127.0.0.1**, otherwise clients can spoof their address.
- Keep the entrypoint on loopback so nothing but the tunnel can reach it.

## Troubleshooting

| Symptom                | Check                                                                    |
| ---------------------- | ------------------------------------------------------------------------ |
| Preflight fails        | Outbound 7844 in the guest, Proxmox and upstream firewall; DNS.          |
| Start fails right away | Token valid and not revoked (`journalctl -u cloudflared`).               |
| Start times out        | UDP blocked and HTTP/2 fallback slow: set `cloudflared_protocol: http2`. |
| `/ready` returns 503   | Tunnel has no active connection; see the journal.                        |
| Version check fails    | `apt-cache policy cloudflared`; is `cloudflared_version` in the repo?    |
