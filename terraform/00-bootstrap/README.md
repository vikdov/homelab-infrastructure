# 00-bootstrap

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.16.0 |
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
| [proxmox_user_token.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/user_token) | resource |
| [proxmox_virtual_environment_file.template_user_data](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_file) | resource |
| [proxmox_virtual_environment_pool.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_pool) | resource |
| [proxmox_virtual_environment_role.terraform](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_role) | resource |
| [proxmox_virtual_environment_user.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_user) | resource |
| [terraform_data.enable_snippets](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_extra_service_accounts"></a> [extra\_service\_accounts](#input\_extra\_service\_accounts) | Additional Proxmox service accounts to create | <pre>map(object({<br/>    comment    = string<br/>    role_id    = string<br/>    path       = optional(string, "/")<br/>    token_name = optional(string, "api")<br/>  }))</pre> | <pre>{<br/>  "ansible": {<br/>    "comment": "Ansible dynamic inventory",<br/>    "role_id": "PVEAuditor"<br/>  },<br/>  "monitoring": {<br/>    "comment": "Prometheus exporter",<br/>    "role_id": "PVEAuditor"<br/>  }<br/>}</pre> | no |
| <a name="input_file_datastore"></a> [file\_datastore](#input\_file\_datastore) | Proxmox storage ID for downloaded files (snippets, cloud-init, ISO, etc.) | `string` | `"local"` | no |
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
<!-- END_TF_DOCS -->
