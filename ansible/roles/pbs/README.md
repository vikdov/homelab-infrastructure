# PBS role: setup and operations

Role `ansible/roles/pbs` · Target: Debian 13 (trixie) LXC guest · Software: Proxmox Backup Server 4 · Companion: `terraform/03-backups` · Last updated: 2026-11-08

## 1. Scope

The role turns a fresh Debian 13 LXC into a Proxmox Backup Server (PBS) and prepares everything Terraform stage 03 needs to connect Proxmox VE to it.

**Managed by the role**

- Proxmox archive keyring and the PBS apt repository: no-subscription by default, enterprise when a subscription key is set
- The `proxmox-backup-server` package and its services
- A tmpfiles entry that keeps `/run/proxmox-backup` owned by the `backup` user (workaround, see section 12)
- Optional: registration of a PBS subscription key
- One datastore with a garbage-collection (GC) schedule
- User `pve-backup@pbs` and token `pve` with `DatastoreBackup` only; the token secret is saved to `/root/pbs-pve-token`
- A prune job (retention) and a verify job
- Optional: UI admin user `admin@pbs`
- Optional: push sync to a second PBS (off-box copy)
- Optional: SMTP notifications for failed jobs

**Not managed (decide separately)**

- The LXC itself (Terraform stage 02), the datastore disk or mount, firewall rules
- The PVE storage entry and the vzdump job (Terraform stage 03)
- The offsite PBS server and its own prune, GC and verify jobs
- PVE-side vzdump failure notifications
- Monitoring that a backup actually ran (a dead PBS sends no email)
- Removing objects: the role creates and updates what it manages and never deletes users, datastores, jobs or ACLs. It also cannot detect a changed password, because PBS never shows one. Rotate passwords and remove objects by hand with `proxmox-backup-manager` or the UI.
- Unregistering a subscription (`proxmox-backup-manager subscription remove`)

## 2. Who owns what

| Item                                             | Owner                                                 |
| ------------------------------------------------ | ----------------------------------------------------- |
| PBS guest (LXC)                                  | Terraform stage 02                                    |
| PBS install, repository choice, subscription key | Ansible (this role); the key lives in the vault       |
| Datastore, users, token, ACLs                    | Ansible (this role)                                   |
| Prune, GC, verify, sync jobs, notifications      | Ansible (this role)                                   |
| PVE storage entry `pbs`, vzdump job `daily-core` | Terraform stage 03                                    |
| Retention policy                                 | PBS only. Terraform sets `keep-all` on the vzdump job |

## 3. Security model

- The PVE token has `DatastoreBackup` only. A compromised PVE host can create backups but cannot prune or delete them. Do not grant `DatastorePowerUser`.
- Permissions are granted to both the user and the token. PBS uses the intersection, so both must be allowed.
- The sync job pushes with `remove-vanished` set to false, and the offsite credential should also have `DatastoreBackup` only. A compromised main PBS cannot delete the offsite copy. Consequence: the offsite PBS needs its own prune, GC and verify jobs.
- The token secret is stored in plaintext in `/root/pbs-pve-token` (root only, mode 0600).
- These commands briefly expose a secret in process arguments: admin user creation, remote creation, SMTP endpoint creation, and subscription key registration (`subscription set <key>`). The tasks use `no_log`. Use vault values and a single-purpose host.
- The Proxmox signing key is pinned by SHA-256 (`pbs_keyring_checksum`, from the Proxmox installation docs). It is verified when downloaded; an existing keyring file is never overwritten. If Proxmox rotates the key the download fails closed: compare the new hash with the docs and update the variable. Emptying the variable falls back to TLS-only trust (warning shown).

## 4. Prerequisites

- **Guest**: stage 02 created the guest named `pbs` (Debian 13, systemd, static IP). Ansible reaches it as user `ansible` with sudo.
- **Storage**: decide where the datastore lives. On the container root disk, a rebuild deletes all backups and a host disk failure loses source and backup together. Use a dedicated mount (LXC mount point, HDD). `pbs_datastore_require_mount` defaults to `true` and checks `pbs_datastore_mountpoint` (the parent of the datastore path, `/srv/pbs` by default), so the datastore sits in a subdirectory of the mount and a fresh filesystem's `lost+found` stays out of it. Check the mount is not `noatime` (garbage collection relies on access times) and, for an unprivileged LXC, that the host directory is owned by the container's mapped `backup` user.
- **Network**: the PVE node reaches `pbs:8007`. For sync, `pbs` reaches the offsite PBS on 8007. For notifications, `pbs` reaches your SMTP server. With a subscription key, `pbs` also reaches the Proxmox subscription server and `enterprise.proxmox.com`. The role manages no firewall rules.
- **Vault**: `vault_pbs_admin_password` (12+ characters). Optional: `vault_pbs_subscription_key`, `vault_pbs_sync_remote_password`, `vault_pbs_smtp_password`.
- **Keyring pin**: already set. Re-check it against Proxmox's installation docs when you upgrade PBS.

## 5. Setup sequence

Apply order: **00, 01, 02, Ansible (PBS), 03.**

### Step 1. Create the guest

Apply Terraform stages 00, 01 and 02 so that the `pbs` guest exists and is reachable over SSH.

### Step 2. Prepare inventory and vault

`inventory/host_vars/pbs/main.yml` (minimum):

```yaml
---
pbs_admin_password: "{{ vault_pbs_admin_password }}"
# Only with a PBS subscription:
# pbs_subscription_key: "{{ vault_pbs_subscription_key }}"
```

Create `inventory/host_vars/pbs/vault.yml` from `vault.yml.example`, then encrypt it:

```bash
ansible-vault encrypt inventory/host_vars/pbs/vault.yml
```

### Step 3. Dry run, then apply

Use the playbook that applies the `pbs` role to the `pbs` host:

```bash
ansible-playbook playbooks/pbs.yml --limit pbs --check --diff --ask-vault-pass
ansible-playbook playbooks/pbs.yml --limit pbs --ask-vault-pass
```

The role installs PBS, creates the datastore, user, token and jobs, and ends with a debug message listing the values Terraform needs. `--check` on a host without PBS skips the configuration part (the role detects an installed package with `dpkg-query`).

With `pbs_subscription_key` set, the first run installs from the no-subscription repository, registers the key, requires the subscription to be `active`, and only then switches to the enterprise repository and removes the no-subscription source.

### Step 4. Collect the handoff values

The last task prints:

```
TF_VAR_pbs_datastore=main
TF_VAR_pbs_fingerprint=AA:BB:...:FF
TF_VAR_pbs_token_secret: ssh pbs 'sudo cat /root/pbs-pve-token'
```

The fingerprint must have 32 colon-separated hex bytes (Terraform validates this). Fetch the secret without putting it in a file:

```bash
export TF_VAR_pbs_token_secret="$(ssh pbs 'sudo cat /root/pbs-pve-token')"
```

### Step 5. Apply Terraform stage 03

Put `pbs_datastore` and `pbs_fingerprint` into `terraform.tfvars`. Keep the secret (and `TF_VAR_pbs_encryption_key` if used) in the environment only.

```bash
cd terraform/03-backups
terraform plan
terraform apply
```

If you enable client-side encryption, store a copy of the key offline. Without it, encrypted backups cannot be restored.

### Step 6. Prove it works

Run one backup from the PVE UI (Datacenter, Backup, Run now), then restore the smallest guest to a new VMID. An unrestored backup is untested. See section 10.

### Step 7. Optional: off-box copy and notifications

See sections 7 and 8. Enable them once a second PBS and an SMTP account exist.

## 6. Variables

Defaults live in `defaults/main.yml`. Override in `host_vars/pbs/main.yml`; secrets go in the vault.

| Variable                                                            | Default                          | Purpose                                                                                                                          |
| ------------------------------------------------------------------- | -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `pbs_keyring_url`                                                   | trixie keyring URL               | Proxmox signing key                                                                                                              |
| `pbs_keyring_checksum`                                              | pinned (trixie keyring)          | `sha256:<hash>`; checked on download only; empty means TLS-only trust                                                            |
| `pbs_subscription_key`                                              | empty                            | Vault. Empty: no-subscription repository, enterprise source written as disabled. Set: key registered, enterprise repository used |
| `pbs_datastore_name`                                                | `main`                           | Must equal Terraform `pbs_datastore`                                                                                             |
| `pbs_datastore_path`                                                | `/srv/pbs/main`                  | Datastore directory                                                                                                              |
| `pbs_datastore_mountpoint`                                          | parent of the datastore path     | Directory that must be a mount point                                                                                             |
| `pbs_datastore_require_mount`                                       | `true`                           | Fail unless `pbs_datastore_mountpoint` is a mount point (set `false` only on purpose)                                            |
| `pbs_prune_schedule`                                                | `04:00`                          | Prune job schedule                                                                                                               |
| `pbs_gc_schedule`                                                   | `sat 05:00`                      | Garbage collection schedule                                                                                                      |
| `pbs_verify_schedule`                                               | `sun 06:00`                      | Verify job schedule                                                                                                              |
| `pbs_verify_outdated_after`                                         | `30`                             | Days before a snapshot is re-verified                                                                                            |
| `pbs_keep`                                                          | daily 7, weekly 4, monthly 6     | Retention                                                                                                                        |
| `pbs_pve_user`                                                      | `pve-backup@pbs`                 | User for PVE                                                                                                                     |
| `pbs_pve_token_name`                                                | `pve`                            | Token name (token ID `pve-backup@pbs!pve`)                                                                                       |
| `pbs_token_file`                                                    | `/root/pbs-pve-token`            | Where the secret is saved                                                                                                        |
| `pbs_token_regenerate`                                              | `false`                          | One-off: delete and recreate the token                                                                                           |
| `pbs_admin_user`                                                    | `admin@pbs`                      | UI admin (realm pbs)                                                                                                             |
| `pbs_admin_password`                                                | empty                            | Vault; empty skips the admin user. Applied only at creation                                                                      |
| `pbs_sync_enabled`                                                  | `false`                          | Enable push sync                                                                                                                 |
| `pbs_sync_remote_*`                                                 | empty                            | Offsite host, auth ID, password (vault), fingerprint, datastore (`pbs_sync_remote_name` defaults to `offsite`)                   |
| `pbs_sync_schedule`                                                 | `08:00`                          | Sync job schedule                                                                                                                |
| `pbs_notify_enabled`                                                | `false`                          | Enable SMTP failure notifications                                                                                                |
| `pbs_notify_smtp_*`, `pbs_notify_from_address`, `pbs_notify_mailto` | empty (port 587, `starttls`)     | SMTP settings (password from the vault)                                                                                          |
| `pbs_notify_endpoint_name`, `pbs_notify_matcher_name`               | `homelab-mail`, `homelab-errors` | Names of the SMTP endpoint and the matcher                                                                                       |
| `pbs_notify_severity`                                               | `error`                          | Matcher severity                                                                                                                 |

Optional: `bootstrap_apt_lock_timeout` (seconds, default 300) if another role defines it.

### Repository logic

| `pbs_subscription_key` | Result                                                                                                                                                               |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| empty                  | No-subscription repository is the permanent source. The `pbs-enterprise` source is written as `Enabled: no` before the install, so it never breaks `apt update`      |
| set, PBS not installed | No-subscription repository is a temporary bootstrap source, because the key can only be registered with `proxmox-backup-manager`, which comes from the package       |
| set, PBS installed     | Key registered if the subscription is not already `active`; the role asserts it is `active`, then writes the enterprise source, removes `pbs.sources`, refreshes apt |

Changing the variable later switches the repositories on the next run. Removing the key switches back to no-subscription but leaves the subscription registered on the host.

### Daily timeline (defaults)

| Time      | Job                    | Owner                         |
| --------- | ---------------------- | ----------------------------- |
| 02:30     | vzdump backup from PVE | Terraform (`backup_schedule`) |
| 04:00     | Prune                  | Ansible                       |
| Sat 05:00 | Garbage collection     | Ansible                       |
| Sun 06:00 | Verify                 | Ansible                       |
| 08:00     | Push sync to offsite   | Ansible                       |

Keep the backup window clear of prune and GC, and run sync after the backup has finished.

## 7. Off-box copy (push sync)

A backup on the same node is not a disaster recovery copy. The sync job pushes snapshots to a second PBS.

**On the offsite PBS (manual, not done by this role)**

1. Install PBS and create a datastore.
2. Create a user and token (for example `push-main@pbs!main`) with `DatastoreBackup` on that datastore only.
3. Create its own prune, GC and verify jobs. Nothing else prunes it, because `remove-vanished` is false.
4. Read its fingerprint with `proxmox-backup-manager cert info`.

**On this role** (`host_vars/pbs/main.yml`)

```yaml
pbs_sync_enabled: true
pbs_sync_remote_host: offsite-pbs.example.net:8007
pbs_sync_remote_auth_id: push-main@pbs!main
pbs_sync_remote_password: "{{ vault_pbs_sync_remote_password }}"
pbs_sync_remote_fingerprint: "AA:BB:...:FF"
pbs_sync_remote_datastore: offsite
```

The role reads the CLI help first and stops with a clear message if the PBS version has no push sync (it needs PBS 4) or if the option names differ from what the role uses.

A changed remote password in the vault is not detected. Update it once by hand with `proxmox-backup-manager remote update <name> --password ...`.

## 8. Failure notifications

The role creates an SMTP endpoint and a matcher that sends job failures (severity `error`) to one address.

```yaml
pbs_notify_enabled: true
pbs_notify_smtp_server: smtp.example.net
pbs_notify_smtp_username: pbs@example.net
pbs_notify_smtp_password: "{{ vault_pbs_smtp_password }}"
pbs_notify_from_address: pbs@example.net
pbs_notify_mailto: you@example.net
```

Test with the Test button on the endpoint (PBS UI, Configuration, Notifications). Then force one real failure and confirm the email arrives.

A changed SMTP password in the vault is not detected. Update it by hand or in the UI.

Limits: a job that never starts sends nothing, and PVE-side vzdump failures use PVE's own notification system, which this repository does not configure.

## 9. Tags, check mode, idempotence

| Tag           | Part                                                                      |
| ------------- | ------------------------------------------------------------------------- |
| `always`      | Package check (`dpkg-query`) that sets `pbs_installed`; runs with any tag |
| `pbs_install` | Keyring, repositories, package, tmpfiles entry, services, subscription    |
| `pbs_config`  | Datastore, users, token, ACLs, jobs, handoff values                       |
| `pbs_sync`    | Remote and sync job                                                       |
| `pbs_notify`  | SMTP endpoint and matcher                                                 |

- Read-only commands run in `--check` too, so the diff shows what would change.
- On a host without PBS, `--check` skips configuration, sync and notifications.
- Settings are read first and written only when they differ, so `changed` means something changed. This includes ACLs: the list is read first and a grant is made only when missing, so a manually removed ACL shows up as a change.
- With a key set, an unreadable subscription status makes the role register the key again on every run, which shows as `changed` (see section 12).
- Run the role twice after any change. The second run must report `changed=0`.

## 10. Verification

**On the PBS guest**

```bash
sudo systemctl is-active proxmox-backup proxmox-backup-proxy
sudo proxmox-backup-manager datastore list
sudo proxmox-backup-manager user list-tokens pve-backup@pbs
sudo proxmox-backup-manager acl list
sudo proxmox-backup-manager prune-job list
sudo proxmox-backup-manager verify-job list
sudo ls -l /root/pbs-pve-token
sudo proxmox-backup-manager cert info
sudo grep -rH -E 'Components|Enabled' /etc/apt/sources.list.d/
sudo proxmox-backup-manager subscription get   # with a key set
```

Expected: both services active; datastore `main` with your GC schedule; token present; `DatastoreBackup` for the user and the token on `/datastore/main`; one prune and one verify job; token file non-empty with mode 0600. Repositories: with no key, only `pbs-no-subscription` enabled and `pbs-enterprise` showing `Enabled: no`; with a key, only `pbs-enterprise` and a subscription status of `active`.

**Reboot test**

1. Reboot the guest.
2. Both services must come back active, and `ls -ld /run/proxmox-backup` must show `backup backup`.
3. `/etc/tmpfiles.d/proxmox-backup-run.conf` must exist.

**End to end**

1. Run a backup from the PVE UI. Confirm the snapshot appears in PBS.
2. Restore the smallest guest to a new VMID and boot it. This is the test that matters.
3. Start the verify job once and confirm it passes.
4. With sync enabled, start the sync job and confirm snapshots appear on the offsite PBS. Restore one from there.
5. Run a prune on main and confirm the offsite snapshots stay.
6. Confirm the PVE token cannot delete. Sources disagree on whether `Datastore.Backup` lets an owner remove its own snapshots (Proxmox staff say no, some write-ups say yes), so test your version. From a machine with `proxmox-backup-client`, using the token: `PBS_PASSWORD=<secret> proxmox-backup-client snapshot forget <type>/<id>/<time> --repository 'pve-backup@pbs!pve@<pbs-host>:main'` on a throwaway snapshot. It must be refused. If it succeeds, rely on the offsite copy and protected snapshots for ransomware resilience, and prefer a pull-based sync from the offsite PBS.

## 11. Day-2 operations

| Task                           | How                                                                                                                                                                                                                                                      |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Change a schedule or retention | Edit the variable, run the role. Prune and verify jobs are updated when they differ                                                                                                                                                                      |
| Add a subscription key         | Set `pbs_subscription_key` and run the role. It registers the key, requires `active`, then switches to the enterprise repository and removes the no-subscription source                                                                                  |
| Remove the subscription key    | Empty the variable and run the role. It writes the no-subscription repository and disables the enterprise source. The subscription stays registered; run `proxmox-backup-manager subscription remove` by hand if you want that gone                      |
| Change the admin password      | Not applied by the role (set only at creation). Change it in the UI or with `proxmox-backup-manager user update`                                                                                                                                         |
| Lost token secret file         | The role stops with a clear message. Rerun once with `-e pbs_token_regenerate=true`, then update `TF_VAR_pbs_token_secret` and reapply stage 03. The old secret stops working immediately                                                                |
| Rebuild the PBS guest          | Re-attach the datastore mount first. The role detects an existing `.chunks` directory and re-adopts the data (`--reuse-datastore`). The fingerprint and token secret change: reapply stage 03 with the new values. On the root disk all backups are gone |
| Update PBS                     | `apt update && apt full-upgrade` on the guest during a window with no running jobs. The role does not update packages                                                                                                                                    |
| Move the datastore to a mount  | Mount first, copy the data (keep ownership), then set `pbs_datastore_path`. An existing datastore at the new path is re-adopted. Changing the path does not move data by itself                                                                          |

## 12. Troubleshooting

| Symptom                                                                           | Likely cause and fix                                                                                                                                                                                                                                                                                                                                   |
| --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `no package matching proxmox-backup-server`                                       | The repository or key was not read. The role refreshes apt when either changes; check `/etc/apt/sources.list.d/pbs.sources` and the keyring file                                                                                                                                                                                                       |
| apt returns 401 for an enterprise source                                          | With no key, `/etc/apt/sources.list.d/pbs-enterprise.sources` should contain `Enabled: no`; rerun the role. With a key, check `proxmox-backup-manager subscription get`                                                                                                                                                                                |
| Stops: `subscription is not active`                                               | The key is invalid or expired, or `pbs` cannot reach the Proxmox subscription server. The repositories are left on no-subscription because the switch happens after this check                                                                                                                                                                         |
| Second run reports `changed` for the subscription key                             | The role could not read the status, so it registers the key again each run. Compare with `proxmox-backup-manager subscription get --output-format json`; the role looks for `"status": "active"`                                                                                                                                                       |
| `proxmox-backup-proxy` fails with `mkstemp ".../proxy.pid.tmp_XXXXXX" ... EACCES` | `/run/proxmox-backup` is `root:root` while the proxy runs as `backup`. The role installs a tmpfiles entry and fixes the directory for the current boot. The root cause was not identified. Manual fix: `sudo chown backup:backup /run/proxmox-backup && sudo systemctl reset-failed proxmox-backup-proxy && sudo systemctl start proxmox-backup-proxy` |
| Stops: token exists but secret file is missing                                    | The secret is shown once. Use `-e pbs_token_regenerate=true`                                                                                                                                                                                                                                                                                           |
| PVE storage cannot connect                                                        | Wrong fingerprint (changed after a rebuild), port 8007 blocked, wrong token secret, or missing ACL for the token                                                                                                                                                                                                                                       |
| Second run shows other changes                                                    | Job or setting JSON keys differ from the role's assumptions. Compare with `proxmox-backup-manager <job> list --output-format json`                                                                                                                                                                                                                     |
| Sync assertion fails                                                              | PBS older than 4 (no push sync) or option names differ. Compare with `proxmox-backup-manager sync-job create --help`                                                                                                                                                                                                                                   |
| Root disk fills up                                                                | Datastore is on the container root disk. Move it to a dedicated mount                                                                                                                                                                                                                                                                                  |
| Stops: `Could not read a SHA-256 fingerprint`                                     | `cert info` output format differs. Run `proxmox-backup-manager cert info` by hand and compare with the role's pattern                                                                                                                                                                                                                                  |

## 13. Known limitations and unverified assumptions

- **Tested against a fake CLI, not real PBS.** The Molecule scenario (section 14) proves the Ansible logic: second run `changed=0`, ACL drift is reported, a rebuilt guest re-adopts its data, a lost token secret stops the run, the mount guard fails. It does not prove that the real CLI accepts the same flags or returns the same JSON keys (`gc-schedule`, `keep-daily`, `outdated-after`, `tokenid`, `auth-id`, `remote-store`, `match-severity`, `ugid`, `roleid`). The scratch-guest test below is the check; a wrong key shows up as `changed` on the second run or as a clear failure.
- **Subscription handling is untested on real PBS.** Three assumptions are unverified: `proxmox-backup-manager subscription get --output-format json` returns a `status` field; `subscription set` leaves the host able to authenticate against the enterprise repository (on Proxmox VE the credentials live in an apt auth file); and a registered key makes `apt update` succeed after the switch. The `active` assertion guards against a bad key, not against missing apt credentials.
- **The disabled enterprise source relies on dpkg keeping a modified config file.** The role writes `pbs-enterprise.sources` before the install and installs with `force-confold`. This works only if the package ships that file as a config file. Check `grep Enabled /etc/apt/sources.list.d/pbs-enterprise.sources` after the first run without a key.
- **`/run/proxmox-backup` ownership.** The tmpfiles entry is a workaround for a failure whose cause is unknown (the directory came up `root:root` after a reboot). It has not been confirmed to survive reboots on every guest; see the reboot test in section 10.
- **Notifications are new.** `notify.yml` follows the PBS notification CLI (`notification endpoint smtp`, `notification matcher`) and checks `--help` first. Send a test (break a job on purpose, or trigger a verify of a corrupted copy) and confirm the mail arrives. A changed SMTP password is not detected.
- **Push sync.** Confirm it is supported and stable on your PBS version before relying on it, and prefer pull from the offsite side if the main PBS could be compromised.
- **Single copy unless sync is enabled.** One PBS plus one offsite copy only if you enable sync. Without it you have a same-node copy.
- **No monitoring of missing runs.** If PBS or the LXC is down, no email is sent. Add an external alert on the age of the newest backup, or a heartbeat.
- **Secrets at rest.** The token secret, the remote password, the SMTP password and the subscription key are stored on the PBS guest, readable by root. The Terraform state also holds the token secret: protect it.
- **Patching.** The role does not update packages. Schedule `apt full-upgrade` (or unattended-upgrades limited to security) in your base role.
- **Role is Debian 13 only.** The platform check fails on any other release because the keyring URL is release-specific.

## 14. Testing

1. **Static**: `cd ansible && yamllint -c .yamllint roles playbooks inventory && ansible-lint` (production profile passes).
2. **Logic (Molecule)**: `pip install molecule molecule-plugins[docker] ansible-lint` then `cd ansible/roles/pbs && molecule test`. Uses a Debian 13 container and a stateful fake `proxmox-backup-manager` (`molecule/default/files/`). Package installation is skipped (`skip-tags: pbs_install`); the `always`-tagged `dpkg-query` check still runs, so the fake scenario must tolerate a missing package. Rerun it after any change to `main.yml` or `install.yml`, and in CI on every change to the role.
3. **Real PBS (before the first production run, and after PBS major upgrades)**: create a throwaway Debian 13 guest with a mount at `/srv/pbs`, run the full role (install included) against it twice, and require `changed=0` the second time. Repeat for three cases:
   - no key;
   - key set (needs a real subscription key);
   - key set, then removed, to confirm the switch back to no-subscription.

   Then do the end-to-end checks in section 10, including the reboot test, a restore, and the delete test.
