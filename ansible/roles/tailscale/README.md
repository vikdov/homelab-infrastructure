# tailscale role

Installs Tailscale from the official apt repository (`pkgs.tailscale.com`) on Debian-family hosts (Debian bullseye/bookworm/trixie, Ubuntu jammy/noble) with systemd, joins the tailnet and runs the node as an IPv4 subnet router.

## Requirements

- Debian or Ubuntu with systemd, Ansible >= 2.15, facts gathered (the role reads `distribution`, `distribution_release`, `service_mgr`).
- `/dev/net/tun` present on the host. In an LXC container it must be passed in from the hypervisor (here by `playbooks/pve.yml`, followed by a container restart). The role fails early if the device is missing.
- Outbound access to `pkgs.tailscale.com` and the Tailscale control plane.
- A Tailscale auth key for the first login (see Setup).

## Variables

| Variable                                            | Default                          | Description                                                                                                                    |
| --------------------------------------------------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `tailscale_hostname`                                | `inventory_hostname`             | Node name in the tailnet (DNS label: letters, digits, hyphens).                                                                |
| `tailscale_authkey`                                 | `""`                             | Auth key, needed only while the node is not logged in. Keep it in the vault.                                                   |
| `tailscale_authkey_file`                            | `/run/tailscale/authkey`         | tmpfs file (mode 0600) the key is staged in for `tailscale up`; removed right after.                                           |
| `tailscale_advertise_routes`                        | `[]`                             | IPv4 CIDRs to advertise. Non-empty enables IPv4 forwarding.                                                                    |
| `tailscale_accept_dns`                              | `false`                          | Let tailscaled manage DNS. Off by default so it does not rewrite `resolv.conf` on a host that runs its own resolver (Pi-hole). |
| `tailscale_accept_routes`                           | `false`                          | Accept routes advertised by other nodes.                                                                                       |
| `tailscale_version`                                 | `""`                             | Exact package version to pin. Empty installs the newest release once and never upgrades.                                       |
| `tailscale_signing_key_checksum`                    | `""`                             | Optional `sha256:<hex>` of the apt signing key. Empty means TLS-only trust.                                                    |
| `tailscale_repo_distro` / `tailscale_repo_codename` | from facts                       | Repository path (`debian`/`ubuntu`) and suite.                                                                                 |
| `tailscale_login_states`                            | `[NeedsLogin, NoState, Unknown]` | Backend states in which an auth key is required.                                                                               |
| `tailscale_up_timeout`                              | `60s`                            | How long `tailscale up` waits for the `Running` state.                                                                         |

Example (`host_vars`):

```yaml
tailscale_hostname: homelab-net
tailscale_authkey: "{{ vault_tailscale_authkey | default('') }}"
tailscale_advertise_routes:
  - 10.10.0.0/16
  - 192.168.1.0/24
```

## Setup

1. In the Tailscale admin console, create an auth key (Settings -> Keys): single-use, pre-approved, short expiry, tagged (e.g. `tag:subnet-router`). A tagged key keeps the node key from expiring.
2. Store it in the vault:

   ```bash
   cp inventory/host_vars/net/vault.yml.example inventory/host_vars/net/vault.yml
   # set vault_tailscale_authkey, then:
   ansible-vault encrypt inventory/host_vars/net/vault.yml
   ```

3. Make sure the TUN device is available on the host (`playbooks/pve.yml` for a Proxmox LXC).
4. Run:

   ```bash
   ansible-playbook playbooks/net.yml --tags tailscale
   ```

5. Approve the advertised routes in the admin console (Machines -> node -> Edit route settings), or add an `autoApprovers` rule to the tailnet policy. The role only prints a reminder; it cannot approve routes.
6. If the tailnet requires device approval, the run stops with a message when the node is in `NeedsMachineAuth`. Approve the device and rerun.

## What it does

**install.yml**: validates platform, hostname and routes; checks `/dev/net/tun`; installs `ca-certificates`; downloads the signing key and writes a deb822 source `/etc/apt/sources.list.d/tailscale.sources`; installs `tailscale` (pinned if `tailscale_version` is set); writes `/etc/sysctl.d/99-tailscale.conf` with `net.ipv4.ip_forward = 1` and applies it (when routes are advertised; the file is removed when the list is empty, but the running value stays until reboot); enables and starts `tailscaled`.

**connect.yml**: waits for `/run/tailscale/tailscaled.sock`; reads `tailscale status --json`; stops on `NeedsMachineAuth`; requires an auth key and a client that supports `--auth-key=file:` when logging in; runs `tailscale up --reset` with hostname, accept-dns, accept-routes and advertise-routes (the key is passed via file, never on the command line); removes the staged key; then runs `tailscale set` to align preferences with the inventory and waits until the state is `Running`.

Because of `--reset`, the inventory is the single source of truth: flags not set by the role are reset to defaults.

## Notes

- IPv4 only: IPv6 CIDRs are rejected and only IPv4 forwarding is enabled.
- Re-runs are idempotent; the auth key is only needed while the node is not logged in.
- With the default (empty) `tailscale_version`, the package is not upgraded by the role. Upgrade manually or pin a version.
- `tailscale_accept_dns: false` matters when Pi-hole is the local resolver.
- Check mode: connect tasks run only if `/usr/bin/tailscale` already exists.

Verify on the host:

```bash
tailscale status
tailscale debug prefs
sysctl net.ipv4.ip_forward
```

## Testing

```bash
cd ansible/roles/tailscale
molecule test                # install only; needs network (pkgs.tailscale.com) and /dev/net/tun on the Docker host
molecule test -s connect     # connect.yml against a stub tailscale CLI; no network or tailnet needed
```

Needs `molecule-plugins[docker]`. The instance is `static-routes-debian12`, using `geerlingguy/docker-debian12-ansible` pinned by digest in `molecule/default/molecule.yml`; change the digest there to test another image. The `default` scenario cannot join a real tailnet; the `connect` scenario checks first login, key handling (file-based, never inline), idempotence and preference alignment against the stub.
