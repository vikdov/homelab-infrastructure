# 03-backups

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.16.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.9.0 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.120.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.120.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [proxmox_backup_job.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/backup_job) | resource |
| [proxmox_storage_pbs.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/storage_pbs) | resource |
| [terraform_data.backup_checks](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_remote_state.workloads](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_backup_enabled"></a> [backup\_enabled](#input\_backup\_enabled) | Set false to keep the storage and job defined but paused. | `bool` | `true` | no |
| <a name="input_backup_exclude_guests"></a> [backup\_exclude\_guests](#input\_backup\_exclude\_guests) | Guest names never backed up (PBS must not back up itself). | `list(string)` | <pre>[<br/>  "pbs"<br/>]</pre> | no |
| <a name="input_backup_mode"></a> [backup\_mode](#input\_backup\_mode) | vzdump mode. | `string` | `"snapshot"` | no |
| <a name="input_backup_notification_mode"></a> [backup\_notification\_mode](#input\_backup\_notification\_mode) | How the job reports results: notification-system (PVE notification targets) or legacy-sendmail. | `string` | `"notification-system"` | no |
| <a name="input_backup_pools"></a> [backup\_pools](#input\_backup\_pools) | Guests whose pool\_id is listed here are backed up. | `list(string)` | <pre>[<br/>  "core",<br/>  "apps"<br/>]</pre> | no |
| <a name="input_backup_schedule"></a> [backup\_schedule](#input\_backup\_schedule) | Proxmox calendar event, e.g. "02:30" or "sun 03:00". | `string` | `"02:30"` | no |
| <a name="input_pbs_datastore"></a> [pbs\_datastore](#input\_pbs\_datastore) | PBS datastore name created by Ansible. | `string` | n/a | yes |
| <a name="input_pbs_encryption_key"></a> [pbs\_encryption\_key](#input\_pbs\_encryption\_key) | Optional client-side encryption key (JSON, from proxmox-backup-client key create).<br/>Supply via TF\_VAR\_pbs\_encryption\_key. Store a copy OFFLINE: without it,<br/>encrypted backups are unrecoverable. Null disables encryption. | `string` | `null` | no |
| <a name="input_pbs_fingerprint"></a> [pbs\_fingerprint](#input\_pbs\_fingerprint) | SHA-256 fingerprint of the PBS certificate (proxmox-backup-manager cert info). | `string` | n/a | yes |
| <a name="input_pbs_guest"></a> [pbs\_guest](#input\_pbs\_guest) | Guest name of the PBS LXC in stage 02; its first static IP is used as the server address. | `string` | `"pbs"` | no |
| <a name="input_pbs_namespace"></a> [pbs\_namespace](#input\_pbs\_namespace) | Optional PBS namespace inside the datastore. | `string` | `null` | no |
| <a name="input_pbs_server"></a> [pbs\_server](#input\_pbs\_server) | Override the PBS address (IP or hostname). Null = first static IP of pbs\_guest. | `string` | `null` | no |
| <a name="input_pbs_token_secret"></a> [pbs\_token\_secret](#input\_pbs\_token\_secret) | Secret of the PBS API token. Supply via TF\_VAR\_pbs\_token\_secret, never tfvars. | `string` | n/a | yes |
| <a name="input_pbs_username"></a> [pbs\_username](#input\_pbs\_username) | PBS API token ID used by PVE, e.g. pve-backup@pbs!pve. Needs DatastoreBackup only (see notes). | `string` | `"pve-backup@pbs!pve"` | no |
| <a name="input_proxmox_endpoint"></a> [proxmox\_endpoint](#input\_proxmox\_endpoint) | Proxmox API endpoint | `string` | n/a | yes |
| <a name="input_proxmox_insecure"></a> [proxmox\_insecure](#input\_proxmox\_insecure) | Skip TLS certificate verification for the Proxmox API | `bool` | `false` | no |
| <a name="input_storage_id"></a> [storage\_id](#input\_storage\_id) | Storage ID of the PBS entry inside Proxmox. | `string` | `"pbs"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_backup_storage_id"></a> [backup\_storage\_id](#output\_backup\_storage\_id) | PVE storage ID of the PBS target. |
| <a name="output_backup_vmids"></a> [backup\_vmids](#output\_backup\_vmids) | VM/CT IDs included in the backup job. |
<!-- END_TF_DOCS -->
