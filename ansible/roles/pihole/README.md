# pihole role

Installs Pi-hole v6 on Debian-family hosts (Debian, Ubuntu) with systemd and manages a defined set
of its settings. Re-runs correct drift in the managed keys, including changes made to them in the
web UI. Settings the role does not manage are left alone.

## Variables

```yaml
# group_vars/pihole/vars.yml (or host_vars)
pihole_installer_ref: "v6.5" # tag of pi-hole/pi-hole
pihole_installer_checksum: "sha256:<64 hex>" # see below
pihole_firewall_ack: true # required while listeningMode is ALL
pihole_inventory_groups: [proxmox_all_lxc, proxmox_all_qemu]
pihole_extra_records: ["192.168.1.254 pve.home.arpa"]

# group_vars/pihole/vault.yml (encrypted)
pihole_web_password: "{{ vault_pihole_web_password }}" # min. 12 characters
```

Not applied to Pi-hole: `pihole_web_port` must match the port Pi-hole actually serves on
(`webserver.port`, default 80); it is only used for readiness waits and the password API check.
`pihole_interface` is used only for the initial installer seed configuration.
Default listening mode is `LOCAL`. NTP is not managed unless explicitly set via `pihole_extra_settings`.

### Computing the installer checksum

```bash
TAG=v6.5
curl -fsSL -o basic-install.sh \
  "https://raw.githubusercontent.com/pi-hole/pi-hole/$TAG/automated%20install/basic-install.sh"
# review basic-install.sh before trusting it
echo "sha256:$(sha256sum basic-install.sh | cut -d' ' -f1)"
```

The checksum pins the installer script only. The installer script then fetches Pi-hole components itself,
so installed component versions are whatever it pulls at execution time.

## Behaviour

- **Install**: Skipped when `/usr/local/bin/pihole` exists. A failed install that already created
  that binary is not retried automatically.
- **Settings**: Live values are read with `pihole-FTL --config`, and only differing keys are written. Running with `--check` lists what would change. `dns.hosts` is managed as a whole list: records added via the web UI will be removed on subsequent runs.
- **Inventory records**: Hosts without an IPv4 `ansible_host` or with a dot (`.`) in their inventory name
  receive no record; a warning message lists any skipped hosts.
- **Restart safety**: A state flag file (`restart-pending`) is written before settings are applied and cleared after the `pihole-FTL` service restart completes, ensuring failed execution does not leave applied configs in an un-restarted state.
- **Password**: On every run, the role verifies that a password hash is present in `pihole-FTL` and tests the current password against the `/api/auth` endpoint. If the hash is missing or authentication fails, it updates the password via `pihole setpassword` and re-verifies. (Note: 2FA is not supported by this automated step).
- **Updates**: Updates are never automatic. Executing `ansible-playbook ... --tags pihole_update` updates to the latest release (`pihole_installer_ref` does not pin updates).
- **Check mode**: Executing in check mode on a host without an existing Pi-hole installation skips setting applications and password validation tasks.

## Not managed (decide separately)

Adlists, groups, and allow/deny lists. Back them up with Teleporter or add custom tasks using the API.
For resolver redundancy, run two hosts and synchronize them with a tool such as `nebula-sync`.

## Testing

`molecule test` requires `molecule-plugins[docker]` and a Docker host that allows privileged systemd containers. The idempotence step (ensuring the second converge reports zero changes) verifies that internal setting normalizations (`__pihole_norm_re`) match real `pihole-FTL` output. Lint with `ansible-lint` and `yamllint`.
