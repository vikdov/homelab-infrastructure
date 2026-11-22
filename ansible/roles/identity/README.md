# identity

Vaultwarden (password manager) and Authelia (SSO / 2FA portal) as a hardened Docker Compose stack
on a Debian 12/13 VM, published as plain HTTP on one internal address for a TLS-terminating edge proxy.

## Requirements

- Debian 12 (bookworm) or 13 (trixie), x86_64 or aarch64.
- The `docker` role has run first (Docker Engine and the Compose plugin >= 2.20). The role fails early
  with a clear message if not.
- `ansible-galaxy collection install -r requirements.yml` (community.docker >= 3.8.0).
- An edge proxy that terminates TLS for `vault.<domain>` and `auth.<domain>` and uses Authelia's
  forward-auth endpoint for everything except the Vaultwarden domain.

## Required variables

| Variable                                  | Notes                                                                                                                  |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `identity_domain`                         | Lower-case DNS name. Vaultwarden is `vault.<domain>`, Authelia `auth.<domain>`.                                        |
| `vaultwarden_version`, `authelia_version` | `x.y.z@sha256:<digest>`. Floating tags are refused; tag-only is refused unless `identity_require_image_digest: false`. |
| `authelia_users`                          | Mapping of username to `{displayname, email, password (argon2id hash), groups}`. Keep in Ansible Vault.                |

Everything else has a safe default; see `defaults/main.yml`. Inputs are validated before anything on
the host is touched, and each failure names the offending variable.

## Security model

- Containers run as an unprivileged uid:gid, with a read-only root filesystem, all capabilities dropped,
  `no-new-privileges`, a noexec `/tmp`, and pid, memory and log-size limits.
- Secrets (`jwt`, `session`, `storage`, and the optional SMTP passwords) are `root:identity 0440` and are
  passed as files (`*_FILE`), never as environment variables. `jwt`, `session` and `storage` are generated
  once on the host, never overwritten and never logged. Each container mounts only the secret files it
  needs: Vaultwarden never sees Authelia's keys.
- Images are pinned by digest. Upgrading is a deliberate version bump.
- Each service runs on its own bridge network. They never talk to each other, so a compromised
  container has no path to its neighbour. Outbound traffic is not filtered (both need SMTP, and
  restricting egress per container subnet is a firewall policy that belongs to the hypervisor).
- Each service carries a hash of its rendered configuration (and secret checksums or passwords) as a
  label, so a config or rotated-secret change recreates only that service.

### Vaultwarden hardening defaults

Restrictive where the risk is real; the deliberate exceptions are called out below (see `defaults/main.yml`):

- Signups closed, password hints disabled, Sends disabled (`vaultwarden_sends_allowed`).
- Emergency access follows SMTP (`vaultwarden_emergency_access_allowed`): off without a mail relay,
  on with one. It lets a designated contact take over a vault after a waiting period and depends on
  mail for the notifications, so it is not enabled where it cannot work.
- Organization creation is **unrestricted by default, on purpose**: with signups closed, every account
  was invited by you, and a shared family or team vault needs organizations. Set
  `vaultwarden_org_creation_users` to `none` or a comma-separated list of admin emails to limit it.
- Outbound HTTP to non-global IPs is blocked, and the internal icon fetcher is off
  (`vaultwarden_icons_enabled: false`): it makes outbound requests to arbitrary domains and reveals
  which sites are stored. Vaultwarden then shows generic icons.
- Login rate limiting is set explicitly (`vaultwarden_login_ratelimit_*`).
- `IP_HEADER_TRUSTED_PROXIES` is set to `identity_allowed_sources`, so only the edge proxy can
  supply the client address that rate limits key on.
- Mail is optional (`vaultwarden_smtp_*`). `vaultwarden_require_device_email` defaults to false because
  it turns a mail outage into a login lockout; enable it only once mail is proven reliable.

### Mail

Authelia and Vaultwarden may use the same relay, but give each its own credentials and sender address
(for example `auth@` and `vault@`), so one compromised container cannot use the other's credential and
messages can be attributed. Keep the SMTP credentials in Ansible Vault, not in the password manager
they enable. Authelia takes a URI (`authelia_smtp_address: submission://host:587`); Vaultwarden takes
host, port and security separately (`vaultwarden_smtp_host`, `_port`, `_security`). Plaintext SMTP is refused.

### Network exposure

The two published ports speak plain HTTP, so they must not be reachable by anything except the edge proxy.
Layer the controls:

1. **Hypervisor firewall** (Proxmox VM firewall). Outside the guest, so a compromised guest cannot change it.
   This is the primary control.
2. **`identity_allowed_sources`** (this role). Docker's published ports are DNAT-ed and forwarded, so they
   **bypass the host's INPUT chain**: an `input`-hook nftables or ufw policy does not protect them. When this
   list is set, the role installs `identity-ingress.service`, which maintains an `IDENTITY-INGRESS` chain
   jumped to from Docker's `DOCKER-USER` chain and drops new connections to the two ports from any other
   source. Connections originating on the VM itself (health checks, Ansible) do not traverse that chain.
   Requires Docker's default iptables backend. Molecule proves enforcement, not just the rule text:
   it connects from a network namespace as an allowed and as a denied source and expects the first to
   connect and the second to be dropped.
3. **Bind address.** The ports are bound to one specific interface address, never `0.0.0.0`.

The hop from the edge proxy to this host is unencrypted. Keep it on a dedicated, firewalled segment or
a WireGuard link; do not route it across a shared network.

Not handled here, because it belongs to the edge proxy: restrict `/admin` on the Vaultwarden vhost to
admin source addresses (it is protected only by the admin token), for example in nginx:

```nginx
location /admin {
    allow 203.0.113.0/24;   # admin workstation or VPN range
    deny  all;
    proxy_pass http://VAULTWARDEN_HOST:8080;
}
```

Also enable HSTS, and make the proxy set
`X-Real-IP` so Vaultwarden's rate limiting sees client addresses rather than the proxy's. If the proxy
reaches this VM through NAT, the address Vaultwarden sees differs from `identity_allowed_sources`; the
header is then ignored and all clients share one rate-limit bucket (it fails safe, but fix the address).
Brute-force banning (fail2ban or CrowdSec) also belongs outside the role; failed logins appear in the
Vaultwarden container log at `warn` level.

## Backup and restore

`identity-backup-dump` (installed to `/usr/local/sbin`) writes integrity-checked SQLite copies to
`/srv/identity/backup/` and updates `/srv/identity/backup/last-success`. Run it as the restic pre-command;
alert if `last-success` is older than your backup interval. The live `db.sqlite3*` files are excluded from
restic so a half-written database is never captured. Back up `/srv/identity/secrets` too: without the
Authelia `storage` key the Authelia database cannot be decrypted.

### Monitoring

`identity-backup-check.timer` runs `identity-backup-check` hourly. It fails, writes an error to the
journal (tag `identity-backup-check`) and leaves the unit in the failed state when:

- the last successful dump is older than `identity_backup_max_age_hours` (default 26, for a daily job), or
- a dump file is missing or empty after a dump has succeeded.

Before the first dump, age is measured from install time, so a fresh deployment gets a grace period
rather than an immediate alert. Alert on `systemctl is-failed identity-backup-check.service` or on the
journal tag with whatever you already run (node_exporter's systemd collector, Alertmanager, a log
shipper). Set `identity_backup_check_enabled: false` to remove it. If the restic job is the thing that
broke, this is how you find out before you need the backup.

Restore (equivalent to what the Molecule restore drill executes):

1. Restore `/srv/identity` (including `secrets/` and `backup/`) from restic.
2. Stop the stack: `docker compose -f /opt/identity/compose.yaml stop`.
3. Install the dumps as the live databases and remove stale journals:

   ```sh
   install -m 0600 -o identity -g identity /srv/identity/backup/vaultwarden.sqlite3 /srv/identity/vaultwarden/db.sqlite3
   install -m 0600 -o identity -g identity /srv/identity/backup/authelia.sqlite3    /srv/identity/authelia/data/db.sqlite3
   rm -f /srv/identity/vaultwarden/db.sqlite3-wal /srv/identity/vaultwarden/db.sqlite3-shm \
         /srv/identity/authelia/data/db.sqlite3-wal /srv/identity/authelia/data/db.sqlite3-shm
   ```

4. Re-run the playbook (or `docker compose ... up -d --wait`) and check both services are healthy.

## Operations

- **Upgrade:** bump `vaultwarden_version` / `authelia_version` (with digests) and run the playbook. Take a backup first.
  Check that the Vaultwarden settings the role writes are supported by the new version: unknown
  environment variables are silently ignored.
- **Add a user:** add an entry (with an argon2id hash) to `authelia_users`; the role recreates Authelia.
- **Rotate `jwt` or `session` secrets:** delete the file and run the playbook; the secret checksum change
  recreates Authelia and invalidates active sessions.
  **Never delete `storage`** without re-encrypting the database first.
- **Rotate an SMTP password:** change it in the vault and run the playbook; only the affected service is recreated.
- **Open registration temporarily:** `vaultwarden_signups_allowed: true`, run, create your account, set it back.
- **Re-enable icon fetching:** `vaultwarden_icons_enabled: true`.

## Known limitations

- Authelia sessions are held in memory: recreating or restarting Authelia signs everyone out. This is
  a deliberate decision, not an omission. Redis would keep sessions across recreations, but it adds a
  stateful service, a secret and a failure mode to a stack whose whole value is being small and
  recoverable, and the cost it removes is one re-login after a deploy. If you run this for many users,
  add Redis in your own overlay.
- Authelia dials its SMTP server at startup and refuses to start if it is unreachable
  (`authelia_notifier_disable_startup_check` exists for tests only). Vaultwarden has no such check,
  unless `vaultwarden_require_device_email` is on, in which case an outage also blocks logins.
- Check mode covers the whole role on a host that already runs the stack. On a fresh host (no `identity`
  account or compose project yet) a dry run cannot create what later tasks depend on, so the role
  validates the inputs, runs the preflight, says so, and skips the rest instead of failing late.
  Molecule checks that a `--check` run on a converged host succeeds and changes nothing.
- The ingress filter needs Docker's iptables backend. With the experimental nftables backend there is no
  `DOCKER-USER` chain; the unit then fails loudly rather than silently doing nothing.
- On reboot there is a short window (typically under a few seconds) between dockerd publishing the
  ports and `identity-ingress.service` applying the rules. This is accepted, with the hypervisor
  firewall as the control that covers it. The unit already starts as soon as `docker.service` is up, so
  a drop-in on `docker.service` would run at about the same moment and gains nothing. Closing the
  window fully means creating the `DOCKER-USER` chain before Docker starts, which would make the
  nftables-backend failure above silent: the chain would exist and do nothing. A loud failure was
  judged worth more than a closed window.
- Images are pinned by digest but their signatures are not verified, and bumping versions is manual.
  Both are left to your supply-chain tooling (a Renovate or Dependabot rule on the version variables
  is the usual fix) rather than baked into the role.

## Testing

Two Molecule scenarios cover the role. Run all Molecule commands from the role directory
(`ansible/roles/identity`): both scenarios locate sibling roles (such as `docker`) through
`ANSIBLE_ROLES_PATH=${MOLECULE_PROJECT_DIRECTORY}/..`.

| Scenario     | Target                       | What it covers                                                                                                                                                                                                                                                                |
| ------------ | ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `validation` | The controller itself, no VM | Input validation (including Vaultwarden mail and org-creation settings): good input is accepted, bad input is rejected with a message naming the offending variable.                                                                                                          |
| `default`    | A disposable Debian VM       | Converge, idempotence, check mode on a converged host, targeted recreation, secret rotation, SMTP, restore drill, backup monitor, optional image upgrade, Docker restart, hardening (containers, networks, Vaultwarden settings), ingress filter enforcement, auth behaviour. |

### Install the tooling

From the repository root:

```sh
mise run setup
```

### Scenario `validation` (no VM)

```sh
cd ansible/roles/identity
molecule test -s validation
```

It runs locally, needs no Docker or facts, and changes nothing. Run it on every change.

### Scenario `default` (disposable VM)

This scenario installs Docker, deletes databases and restarts the Docker daemon. It must only run
against a throwaway VM that you provide. Containers are deliberately not used as the test
instance: systemd, dockerd and iptables are needed.

**1. Prepare the VM.** Use a fresh Debian 12 or 13 VM reachable over SSH as root (or set
`MOLECULE_TARGET_USER` to a user with sudo). Create the safety marker; without it the
scenario refuses to run (`molecule/default/guard.yml`):

```sh
printf %s MOLECULE_DISPOSABLE_IDENTITY_TARGET | sudo tee /etc/identity-molecule-disposable > /dev/null
sudo chown root:root /etc/identity-molecule-disposable
sudo chmod 0644 /etc/identity-molecule-disposable
```

**2. Take a snapshot.** The sequence has no destroy stage and `side_effect` is destructive,
so the VM is left in its final state. Roll back to this snapshot before every clean run.

**3. Set the environment on the controller.** Generate a test hash first:

```sh
docker run --rm authelia/authelia:<tag> authelia crypto hash generate argon2 --password 'test-password'
```

Use single quotes for any value containing `$`, so the shell does not expand it:

```sh
# Required
export MOLECULE_TARGET_HOST=192.0.2.50                      # IP or hostname of the VM
export MOLECULE_VAULTWARDEN_VERSION=1.37.5                  # tag-only is accepted in tests
export MOLECULE_AUTHELIA_VERSION=4.39.28
export MOLECULE_AUTHELIA_TEST_HASH='$argon2id$v=19$...'     # hash of the test password

# Optional
export MOLECULE_TARGET_USER=root                            # default: root
export MOLECULE_AUTHELIA_TEST_PASSWORD='test-password'      # enables the first-factor login tests
export MOLECULE_VAULTWARDEN_TEST_ADMIN_HASH='$argon2id$...' # enables the ADMIN_TOKEN quoting test
                                                            # (a REAL hash: vaultwarden /vaultwarden hash)
export MOLECULE_VAULTWARDEN_UPGRADE_VERSION=<newer tag>     # with the next one, enables the upgrade test
export MOLECULE_AUTHELIA_UPGRADE_VERSION=<newer tag>
```

Optional tests are skipped when their variable is unset. The run prints what is not covered, and with
`MOLECULE_REQUIRE_FULL=true` it refuses to start instead, so a release run cannot go green without
login, admin-token quoting and upgrade coverage:

```sh
export MOLECULE_REQUIRE_FULL=true
```

**4. Run.**

```sh
cd ansible/roles/identity
molecule test
```

The sequence is `syntax, converge, idempotence, side_effect, verify`; `side_effect` begins with a `--check` run on the converged host. For faster iteration run
single stages (`molecule converge`, `molecule idempotence`, `molecule verify`). Note that
`side_effect` changes VM state, so roll back the snapshot before re-running a full sequence.

### Continuous integration

`.github/workflows/identity.yml` runs lint and the `validation` scenario on every change under
`ansible/`. The `default` scenario needs a disposable VM and is not run there: run it with
`MOLECULE_REQUIRE_FULL=true` before a release. (The workflow assumes GitHub Actions; the commands are
plain and port to any runner.)

### Linting

From the `ansible/` root, where the lint configuration lives:

```sh
ansible-lint && yamllint .
```

### What a passing run does not prove

Molecule validates the role on a single disposable VM with a documentation-range allowed source
(`192.0.2.10`). It does not exercise the real edge proxy, the hypervisor firewall, restic
(the dump script is run directly, not through the restic role), real mail delivery (Vaultwarden's
`SMTP_PASSWORD_FILE` handling should be confirmed against your pinned image), a fresh-host check-mode
run, or the reboot window described under Known limitations.
