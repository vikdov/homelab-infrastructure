# static_routes role

Manages IPv4 static routes on Debian-family hosts (Debian bullseye/bookworm/trixie, Ubuntu jammy/noble) through a systemd oneshot unit (`homelab-static-routes`). Routes survive reboots and are retried at boot until the interface and gateway are up.

## Ownership model

Every route the role installs is tagged with a routing protocol number (`static_routes_proto`, default `201`). The role only ever adds, replaces or removes routes carrying that marker. Routes of any other protocol (kernel, DHCP, `proto static`, manually added) are never touched.

Pick a number that is not already in use (see `/etc/iproute2/rt_protos`).

## Variables

| Variable                | Default | Description                                                                                                                                           |
| ----------------------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `static_routes_list`    | `[]`    | Routes to install. Each item needs `to` (IPv4 CIDR), `via` (IPv4 gateway) and `dev` (interface). An empty list removes the unit and all owned routes. |
| `static_routes_proto`   | `201`   | Protocol marker, 1-255.                                                                                                                               |
| `static_routes_retries` | `30`    | Seconds to keep retrying each route at boot.                                                                                                          |

IPv4 only. Input is validated before anything is changed; an invalid route fails the run with `Invalid route ...`.

Example (`host_vars`):

```yaml
static_routes_list:
  - { to: 10.10.0.0/16, via: 10.10.10.1, dev: eth1 }
```

## Usage

```yaml
- hosts: net
  become: true
  roles:
    - role: static_routes
      tags: [static_routes]
```

Run only this role: `ansible-playbook playbooks/net.yml --tags static_routes`

## What it does

1. Validates `static_routes_list`, `static_routes_proto` and `static_routes_retries`.
2. If the list is empty and the unit exists: stops and disables it (`ExecStop` flushes owned routes), then removes the unit and script.
3. Otherwise: installs `iproute2`, deploys `/usr/local/sbin/homelab-static-routes` and `/etc/systemd/system/homelab-static-routes.service`, enables and starts the unit.
4. Changed script or unit triggers a reload, which re-syncs without flushing: wanted routes are added/replaced first, then stale owned routes are deleted, so routes that stay never drop.
5. Verifies that every configured route is present under the protocol marker (skipped in check mode).

Inspect on the host:

```bash
systemctl status homelab-static-routes
ip -4 route show proto 201
```

## Notes

- `TimeoutStartSec` is `routes x retries + 30` seconds.
- The unit is `After=`/`Wants=network-online.target`.
- A route still failing after the retries makes the unit fail; check `journalctl -u homelab-static-routes`.
- `/32` routes are shown by `ip route` without the prefix length; the role accounts for this.
- Removing an entry from the list deletes that route on the next run; stopping the unit flushes all owned routes.

## Testing

```bash
cd ansible/roles/static_routes
molecule test
```

Needs `molecule-plugins[docker]` and a Docker host that allows privileged systemd containers (`NET_ADMIN` for `ip route`). The instance is `static-routes-debian12`, using `geerlingguy/docker-debian12-ansible` pinned by digest in `molecule/default/molecule.yml`; change the digest there to test another image. The scenario covers: install of two routes, shrinking the list (stale route removed, kept and foreign routes survive), empty list (unit and owned routes removed), and rejection of an invalid route.
