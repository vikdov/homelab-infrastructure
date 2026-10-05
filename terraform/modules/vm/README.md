# vm

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
| [proxmox_virtual_environment_vm.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cores"></a> [cores](#input\_cores) | Virtual CPU cores | `number` | n/a | yes |
| <a name="input_datastore_id"></a> [datastore\_id](#input\_datastore\_id) | Datastore used for the VM boot disk and cloud-init data | `string` | n/a | yes |
| <a name="input_disk_gb"></a> [disk\_gb](#input\_disk\_gb) | Boot disk size in GB | `number` | n/a | yes |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | DNS servers configured through cloud-init | `list(string)` | `[]` | no |
| <a name="input_extra_disks"></a> [extra\_disks](#input\_extra\_disks) | Additional VM disks, attached as scsi1, scsi2, etc. | <pre>list(object({<br/>    size_gb      = number<br/>    datastore_id = string<br/>  }))</pre> | `[]` | no |
| <a name="input_image_file_id"></a> [image\_file\_id](#input\_image\_file\_id) | File ID of the downloaded image (e.g. local:iso/debian13.qcow2) used if template\_vm\_id is null. | `string` | `null` | no |
| <a name="input_memory_mb"></a> [memory\_mb](#input\_memory\_mb) | VM memory in MB | `number` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | VM name and hostname | `string` | n/a | yes |
| <a name="input_networks"></a> [networks](#input\_networks) | One entry per NIC, in order. ip is CIDR or "dhcp". | <pre>list(object({<br/>    bridge  = string<br/>    ip      = string<br/>    gateway = optional(string)<br/>  }))</pre> | n/a | yes |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | Proxmox node on which the VM is created | `string` | n/a | yes |
| <a name="input_on_boot"></a> [on\_boot](#input\_on\_boot) | Start the VM automatically when the Proxmox node boots | `bool` | `false` | no |
| <a name="input_pool_id"></a> [pool\_id](#input\_pool\_id) | Proxmox resource pool for the VM | `string` | `null` | no |
| <a name="input_ssh_public_keys"></a> [ssh\_public\_keys](#input\_ssh\_public\_keys) | SSH public keys injected into the VM through cloud-init | `list(string)` | n/a | yes |
| <a name="input_started"></a> [started](#input\_started) | Whether the VM should be running after creation | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Proxmox tags assigned to the VM | `list(string)` | `[]` | no |
| <a name="input_template_vm_id"></a> [template\_vm\_id](#input\_template\_vm\_id) | VM ID of the template used to clone this guest | `number` | `null` | no |
| <a name="input_username"></a> [username](#input\_username) | Initial cloud-init user | `string` | `"debian"` | no |
| <a name="input_vendor_data_file_id"></a> [vendor\_data\_file\_id](#input\_vendor\_data\_file\_id) | Optional Proxmox snippet containing cloud-init vendor data | `string` | `null` | no |
| <a name="input_vm_id"></a> [vm\_id](#input\_vm\_id) | Proxmox VM ID | `number` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
