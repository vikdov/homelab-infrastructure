# 01-platform

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

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [proxmox_download_file.downloaded_lxc_templates](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/download_file) | resource |
| [proxmox_download_file.downloaded_vm_images](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/download_file) | resource |
| [proxmox_sdn_applier.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/sdn_applier) | resource |
| [proxmox_sdn_subnet.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/sdn_subnet) | resource |
| [proxmox_sdn_vnet.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/sdn_vnet) | resource |
| [proxmox_sdn_zone_simple.homelab](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/sdn_zone_simple) | resource |
| [proxmox_virtual_environment_vm.template](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | List of DNS servers for all created guests | `list(string)` | <pre>[<br/>  "1.1.1.1",<br/>  "9.9.9.9"<br/>]</pre> | no |
| <a name="input_file_datastore"></a> [file\_datastore](#input\_file\_datastore) | Proxmox datastore for imported images, LXC templates and cloud-init snippets | `string` | `"local"` | no |
| <a name="input_lxc_templates"></a> [lxc\_templates](#input\_lxc\_templates) | LXC template archives available to platform containers. | <pre>map(object({<br/>    description        = optional(string)<br/>    download_url       = string<br/>    file_name          = optional(string)<br/>    checksum           = optional(string)<br/>    checksum_algorithm = optional(string, "sha256")<br/>  }))</pre> | <pre>{<br/>  "debian13": {<br/>    "description": "Debian 13 LXC template",<br/>    "download_url": "http://download.proxmox.com/images/system/debian-13-standard_13.6-1_amd64.tar.zst"<br/>  }<br/>}</pre> | no |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | Proxmox node name | `string` | `"pve"` | no |
| <a name="input_proxmox_endpoint"></a> [proxmox\_endpoint](#input\_proxmox\_endpoint) | Proxmox API endpoint | `string` | n/a | yes |
| <a name="input_proxmox_insecure"></a> [proxmox\_insecure](#input\_proxmox\_insecure) | Skip TLS certificate verification for the Proxmox API | `bool` | `false` | no |
| <a name="input_template_bridge"></a> [template\_bridge](#input\_template\_bridge) | Bridge/VNet attached to platform VM templates. | `string` | `"vmbr0"` | no |
| <a name="input_template_user_data_file_name"></a> [template\_user\_data\_file\_name](#input\_template\_user\_data\_file\_name) | Cloud-init snippet created in 00-bootstrap | `string` | `"template-qemu-guest-agent.yaml"` | no |
| <a name="input_template_vm_id_map"></a> [template\_vm\_id\_map](#input\_template\_vm\_id\_map) | Optional map of VM image keys to explicit VM IDs for templates. When empty, a template is created for every VM image. | `map(number)` | `{}` | no |
| <a name="input_vm_datastore"></a> [vm\_datastore](#input\_vm\_datastore) | Datastore for VM and LXC root disks | `string` | `"local-lvm"` | no |
| <a name="input_vm_images"></a> [vm\_images](#input\_vm\_images) | VM operating-system images used to build Proxmox VM templates. | <pre>map(object({<br/>    description        = optional(string)<br/>    download_url       = string<br/>    file_name          = optional(string)<br/>    checksum           = optional(string)<br/>    checksum_algorithm = optional(string, "sha256")<br/>  }))</pre> | <pre>{<br/>  "debian13": {<br/>    "description": "debian-13-genericcloud-amd64 generic cloud image",<br/>    "download_url": "https://cloud.debian.org/images/cloud/trixie/20260914-2601/debian-13-genericcloud-amd64-20260914-2601.qcow2"<br/>  }<br/>}</pre> | no |
| <a name="input_vnets"></a> [vnets](#input\_vnets) | Homelab SDN VNets and their IPv4 gateways | <pre>map(object({<br/>    alias   = string<br/>    cidr    = string<br/>    gateway = string<br/>  }))</pre> | <pre>{<br/>  "apps": {<br/>    "alias": "User apps",<br/>    "cidr": "10.10.30.0/24",<br/>    "gateway": "10.10.30.1"<br/>  },<br/>  "dmz": {<br/>    "alias": "DMZ - edge",<br/>    "cidr": "10.10.20.0/24",<br/>    "gateway": "10.10.20.1"<br/>  },<br/>  "infra": {<br/>    "alias": "Infrastructure",<br/>    "cidr": "10.10.10.0/24",<br/>    "gateway": "10.10.10.1"<br/>  },<br/>  "k8s": {<br/>    "alias": "k3s cluster",<br/>    "cidr": "10.10.40.0/24",<br/>    "gateway": "10.10.40.1"<br/>  },<br/>  "lab": {<br/>    "alias": "Lab",<br/>    "cidr": "10.10.50.0/24",<br/>    "gateway": "10.10.50.1"<br/>  }<br/>}</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_dns_servers"></a> [dns\_servers](#output\_dns\_servers) | List of DNS servers used for created guests |
| <a name="output_downloaded_lxc_templates"></a> [downloaded\_lxc\_templates](#output\_downloaded\_lxc\_templates) | LXC template archives downloaded and managed by the platform stage. |
| <a name="output_downloaded_vm_images"></a> [downloaded\_vm\_images](#output\_downloaded\_vm\_images) | VM OS images downloaded and managed by the platform stage. |
| <a name="output_file_datastore"></a> [file\_datastore](#output\_file\_datastore) | The datastore used for ISOs, LXC templates, and cloud-init snippets. |
| <a name="output_node_name"></a> [node\_name](#output\_node\_name) | The Proxmox target node name used across platform resources. |
| <a name="output_vm_datastore"></a> [vm\_datastore](#output\_vm\_datastore) | The datastore used for VM and container root disks. |
| <a name="output_vm_templates"></a> [vm\_templates](#output\_vm\_templates) | VM templates created by the platform stage, keyed by logical OS image name. |
| <a name="output_vnets"></a> [vnets](#output\_vnets) | Map of created VNets and their properties, consumable by workload stages. |
<!-- END_TF_DOCS -->
