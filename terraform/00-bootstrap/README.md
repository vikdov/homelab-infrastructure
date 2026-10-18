## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.16.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.9.0 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.114.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.114.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [proxmox_acl.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/acl) | resource |
| [proxmox_acme_account.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/acme_account) | resource |
| [proxmox_acme_certificate.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/acme_certificate) | resource |
| [proxmox_acme_dns_plugin.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/acme_dns_plugin) | resource |
| [proxmox_apt_repository.disabled](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/apt_repository) | resource |
| [proxmox_apt_standard_repository.no_subscription](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/apt_standard_repository) | resource |
| [proxmox_user_token.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/user_token) | resource |
| [proxmox_virtual_environment_dns.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_dns) | resource |
| [proxmox_virtual_environment_file.template_user_data](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_file) | resource |
| [proxmox_virtual_environment_pool.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_pool) | resource |
| [proxmox_virtual_environment_role.terraform](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_role) | resource |
| [proxmox_virtual_environment_time.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_time) | resource |
| [proxmox_virtual_environment_user.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_user) | resource |
| [terraform_data.acme_checks](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.enable_snippets](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_acme_account_name"></a> [acme\_account\_name](#input\_acme\_account\_name) | Name of the ACME account inside Proxmox. | `string` | `"default"` | no |
| <a name="input_acme_contact"></a> [acme\_contact](#input\_acme\_contact) | Contact e-mail for Let's Encrypt expiry notices. Supply via TF\_VAR\_acme\_contact; do not commit. | `string` | `null` | no |
| <a name="input_acme_directory"></a> [acme\_directory](#input\_acme\_directory) | ACME directory URL. Use the staging directory first to avoid production<br/>rate limits while testing (staging certificates are NOT browser-trusted).<br/>Changing it re-registers the account.<br/>  staging:    https://acme-staging-v02.api.letsencrypt.org/directory<br/>  production: https://acme-v02.api.letsencrypt.org/directory | `string` | `"https://acme-v02.api.letsencrypt.org/directory"` | no |
| <a name="input_acme_dns_api"></a> [acme\_dns\_api](#input\_acme\_dns\_api) | acme.sh DNS API script name (duckdns, desec, cloudflare, ...). | `string` | `"duckdns"` | no |
| <a name="input_acme_dns_data"></a> [acme\_dns\_data](#input\_acme\_dns\_data) | Credentials for the DNS API, as the acme.sh variable names it expects,<br/>e.g. { DuckDNS\_Token = "..." } (deSEC: { DEDYN\_TOKEN = "..." }).<br/>Supply via TF\_VAR\_acme\_dns\_data='{"DuckDNS\_Token":"..."}'. Stored in state. | `map(string)` | `{}` | no |
| <a name="input_acme_dns_plugin_id"></a> [acme\_dns\_plugin\_id](#input\_acme\_dns\_plugin\_id) | ID of the DNS plugin entry inside Proxmox. | `string` | `"duckdns"` | no |
| <a name="input_acme_domain"></a> [acme\_domain](#input\_acme\_domain) | FQDN of the free subdomain (e.g. myhomelab.duckdns.org). Its A record should resolve to the PVE host. | `string` | `null` | no |
| <a name="input_acme_enabled"></a> [acme\_enabled](#input\_acme\_enabled) | Order and install a Let's Encrypt certificate for the PVE web/API endpoint. | `bool` | `false` | no |
| <a name="input_acme_tos_url"></a> [acme\_tos\_url](#input\_acme\_tos\_url) | Let's Encrypt terms-of-service URL accepted when registering the account. Get the current one from the directory URL's `meta.termsOfService`. | `string` | `null` | no |
| <a name="input_apt_disabled_repositories"></a> [apt\_disabled\_repositories](#input\_apt\_disabled\_repositories) | Existing apt repository entries to disable (enterprise repos need a subscription). | <pre>list(object({<br/>    file_path = string<br/>    index     = optional(number, 0)<br/>  }))</pre> | <pre>[<br/>  {<br/>    "file_path": "/etc/apt/sources.list.d/pve-enterprise.sources"<br/>  },<br/>  {<br/>    "file_path": "/etc/apt/sources.list.d/ceph.sources"<br/>  }<br/>]</pre> | no |
| <a name="input_extra_service_accounts"></a> [extra\_service\_accounts](#input\_extra\_service\_accounts) | Additional Proxmox service accounts to create | <pre>map(object({<br/>    comment    = string<br/>    role_id    = string<br/>    path       = optional(string, "/")<br/>    token_name = optional(string, "api")<br/>  }))</pre> | <pre>{<br/>  "ansible": {<br/>    "comment": "Ansible dynamic inventory",<br/>    "role_id": "PVEAuditor"<br/>  },<br/>  "monitoring": {<br/>    "comment": "Prometheus exporter",<br/>    "role_id": "PVEAuditor"<br/>  }<br/>}</pre> | no |
| <a name="input_file_datastore"></a> [file\_datastore](#input\_file\_datastore) | Proxmox storage ID for downloaded files (snippets, cloud-init, ISO, etc.) | `string` | `"local"` | no |
| <a name="input_host_dns_domain"></a> [host\_dns\_domain](#input\_host\_dns\_domain) | Search domain for the PVE host. home.arpa is reserved for home networks (RFC 8375). | `string` | `"home.arpa"` | no |
| <a name="input_host_dns_servers"></a> [host\_dns\_servers](#input\_host\_dns\_servers) | Resolvers for the PVE host (PVE accepts at most three), tried in order.<br/>Pi-hole (guest "net") comes first so the host resolves local names.<br/>While it is down (host boot, restore, maintenance), each lookup waits<br/>for the first server to time out before falling through to the public<br/>resolvers, so the host stays functional but slow.<br/>For a host that never depends on a guest, drop the first entry. | `list(string)` | <pre>[<br/>  "192.168.1.100",<br/>  "1.1.1.1",<br/>  "9.9.9.9"<br/>]</pre> | no |
| <a name="input_host_time_zone"></a> [host\_time\_zone](#input\_host\_time\_zone) | Host time zone (tz database name). Backup schedules are evaluated in this zone. | `string` | `"Europe/Warsaw"` | no |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | Proxmox node name | `string` | `"pve"` | no |
| <a name="input_pools"></a> [pools](#input\_pools) | Resource pools; ACLs can later be scoped per pool | `map(string)` | <pre>{<br/>  "apps": "User applications (VM 200)",<br/>  "core": "Always-on infrastructure (LXC 100/101/110/111, VM 120)",<br/>  "k3s": "Kubernetes cluster (VMs 301-303)",<br/>  "lab": "Scratch / testing (400+)"<br/>}</pre> | no |
| <a name="input_proxmox_endpoint"></a> [proxmox\_endpoint](#input\_proxmox\_endpoint) | Proxmox API URL, e.g. https://pve.lan:8006/ | `string` | n/a | yes |
| <a name="input_proxmox_insecure"></a> [proxmox\_insecure](#input\_proxmox\_insecure) | Skip TLS verification (self-signed certificate) | `bool` | `false` | no |
| <a name="input_proxmox_password"></a> [proxmox\_password](#input\_proxmox\_password) | Proxmox password | `string` | n/a | yes |
| <a name="input_proxmox_username"></a> [proxmox\_username](#input\_proxmox\_username) | Proxmox username | `string` | `"root@pam"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_api_tokens"></a> [api\_tokens](#output\_api\_tokens) | Full API token strings per service account (user@pve!api=secret). |
| <a name="output_pve_url"></a> [pve\_url](#output\_pve\_url) | Trusted URL of the PVE web UI/API (null when ACME is disabled). |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.16.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.9.0 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.114.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.114.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [proxmox_acl.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/acl) | resource |
| [proxmox_acme_account.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/acme_account) | resource |
| [proxmox_acme_certificate.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/acme_certificate) | resource |
| [proxmox_acme_dns_plugin.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/acme_dns_plugin) | resource |
| [proxmox_apt_repository.disabled](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/apt_repository) | resource |
| [proxmox_apt_standard_repository.no_subscription](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/apt_standard_repository) | resource |
| [proxmox_user_token.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/user_token) | resource |
| [proxmox_virtual_environment_dns.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_dns) | resource |
| [proxmox_virtual_environment_file.template_user_data](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_file) | resource |
| [proxmox_virtual_environment_pool.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_pool) | resource |
| [proxmox_virtual_environment_role.terraform](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_role) | resource |
| [proxmox_virtual_environment_time.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_time) | resource |
| [proxmox_virtual_environment_user.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_user) | resource |
| [terraform_data.acme_checks](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.enable_snippets](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_acme_account_name"></a> [acme\_account\_name](#input\_acme\_account\_name) | Name of the ACME account inside Proxmox. | `string` | `"default"` | no |
| <a name="input_acme_contact"></a> [acme\_contact](#input\_acme\_contact) | Contact e-mail for Let's Encrypt expiry notices. Supply via TF\_VAR\_acme\_contact; do not commit. | `string` | `null` | no |
| <a name="input_acme_directory"></a> [acme\_directory](#input\_acme\_directory) | ACME directory URL. Use the staging directory first to avoid production<br/>rate limits while testing (staging certificates are NOT browser-trusted).<br/>Changing it re-registers the account.<br/>  staging:    https://acme-staging-v02.api.letsencrypt.org/directory<br/>  production: https://acme-v02.api.letsencrypt.org/directory | `string` | `"https://acme-v02.api.letsencrypt.org/directory"` | no |
| <a name="input_acme_dns_api"></a> [acme\_dns\_api](#input\_acme\_dns\_api) | acme.sh DNS API script name (duckdns, desec, cloudflare, ...). | `string` | `"duckdns"` | no |
| <a name="input_acme_dns_data"></a> [acme\_dns\_data](#input\_acme\_dns\_data) | Credentials for the DNS API, as the acme.sh variable names it expects,<br/>e.g. { DuckDNS\_Token = "..." } (deSEC: { DEDYN\_TOKEN = "..." }).<br/>Supply via TF\_VAR\_acme\_dns\_data='{"DuckDNS\_Token":"..."}'. Stored in state. | `map(string)` | `{}` | no |
| <a name="input_acme_dns_plugin_id"></a> [acme\_dns\_plugin\_id](#input\_acme\_dns\_plugin\_id) | ID of the DNS plugin entry inside Proxmox. | `string` | `"duckdns"` | no |
| <a name="input_acme_domain"></a> [acme\_domain](#input\_acme\_domain) | FQDN of the free subdomain (e.g. myhomelab.duckdns.org). Its A record should resolve to the PVE host. | `string` | `null` | no |
| <a name="input_acme_enabled"></a> [acme\_enabled](#input\_acme\_enabled) | Order and install a Let's Encrypt certificate for the PVE web/API endpoint. | `bool` | `false` | no |
| <a name="input_acme_tos_url"></a> [acme\_tos\_url](#input\_acme\_tos\_url) | Let's Encrypt terms-of-service URL accepted when registering the account. Get the current one from the directory URL's `meta.termsOfService`. | `string` | `null` | no |
| <a name="input_apt_disabled_repositories"></a> [apt\_disabled\_repositories](#input\_apt\_disabled\_repositories) | Existing apt repository entries to disable (enterprise repos need a subscription). | <pre>list(object({<br/>    file_path = string<br/>    index     = optional(number, 0)<br/>  }))</pre> | <pre>[<br/>  {<br/>    "file_path": "/etc/apt/sources.list.d/pve-enterprise.sources"<br/>  },<br/>  {<br/>    "file_path": "/etc/apt/sources.list.d/ceph.sources"<br/>  }<br/>]</pre> | no |
| <a name="input_extra_service_accounts"></a> [extra\_service\_accounts](#input\_extra\_service\_accounts) | Additional Proxmox service accounts to create | <pre>map(object({<br/>    comment    = string<br/>    role_id    = string<br/>    path       = optional(string, "/")<br/>    token_name = optional(string, "api")<br/>  }))</pre> | <pre>{<br/>  "ansible": {<br/>    "comment": "Ansible dynamic inventory",<br/>    "role_id": "PVEAuditor"<br/>  },<br/>  "monitoring": {<br/>    "comment": "Prometheus exporter",<br/>    "role_id": "PVEAuditor"<br/>  }<br/>}</pre> | no |
| <a name="input_file_datastore"></a> [file\_datastore](#input\_file\_datastore) | Proxmox storage ID for downloaded files (snippets, cloud-init, ISO, etc.) | `string` | `"local"` | no |
| <a name="input_host_dns_domain"></a> [host\_dns\_domain](#input\_host\_dns\_domain) | Search domain for the PVE host. home.arpa is reserved for home networks (RFC 8375). | `string` | `"home.arpa"` | no |
| <a name="input_host_dns_servers"></a> [host\_dns\_servers](#input\_host\_dns\_servers) | Resolvers for the PVE host (PVE accepts at most three), tried in order.<br/>Pi-hole (guest "net") comes first so the host resolves local names.<br/>While it is down (host boot, restore, maintenance), each lookup waits<br/>for the first server to time out before falling through to the public<br/>resolvers, so the host stays functional but slow.<br/>For a host that never depends on a guest, drop the first entry. | `list(string)` | <pre>[<br/>  "192.168.1.100",<br/>  "1.1.1.1",<br/>  "9.9.9.9"<br/>]</pre> | no |
| <a name="input_host_time_zone"></a> [host\_time\_zone](#input\_host\_time\_zone) | Host time zone (tz database name). Backup schedules are evaluated in this zone. | `string` | `"Europe/Warsaw"` | no |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | Proxmox node name | `string` | `"pve"` | no |
| <a name="input_pools"></a> [pools](#input\_pools) | Resource pools; ACLs can later be scoped per pool | `map(string)` | <pre>{<br/>  "apps": "User applications (VM 200)",<br/>  "core": "Always-on infrastructure (LXC 100/101/110/111, VM 120)",<br/>  "k3s": "Kubernetes cluster (VMs 301-303)",<br/>  "lab": "Scratch / testing (400+)"<br/>}</pre> | no |
| <a name="input_proxmox_endpoint"></a> [proxmox\_endpoint](#input\_proxmox\_endpoint) | Proxmox API URL, e.g. https://pve.lan:8006/ | `string` | n/a | yes |
| <a name="input_proxmox_insecure"></a> [proxmox\_insecure](#input\_proxmox\_insecure) | Skip TLS verification (self-signed certificate) | `bool` | `false` | no |
| <a name="input_proxmox_password"></a> [proxmox\_password](#input\_proxmox\_password) | Proxmox password | `string` | n/a | yes |
| <a name="input_proxmox_username"></a> [proxmox\_username](#input\_proxmox\_username) | Proxmox username | `string` | `"root@pam"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_api_tokens"></a> [api\_tokens](#output\_api\_tokens) | Full API token strings per service account (user@pve!api=secret). |
| <a name="output_pve_url"></a> [pve\_url](#output\_pve\_url) | Trusted URL of the PVE web UI/API (null when ACME is disabled). |
<!-- END_TF_DOCS -->
