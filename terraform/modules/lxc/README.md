# lxc

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
| [proxmox_virtual_environment_container.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_container) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cores"></a> [cores](#input\_cores) | Allocated CPU cores | `number` | n/a | yes |
| <a name="input_datastore_id"></a> [datastore\_id](#input\_datastore\_id) | Datastore used for the container root filesystem | `string` | n/a | yes |
| <a name="input_disk_gb"></a> [disk\_gb](#input\_disk\_gb) | Root filesystem size in GB | `number` | n/a | yes |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | DNS servers configured inside the container | `list(string)` | `[]` | no |
| <a name="input_memory_mb"></a> [memory\_mb](#input\_memory\_mb) | Dedicated RAM in MB | `number` | n/a | yes |
| <a name="input_mount_options"></a> [mount\_options](#input\_mount\_options) | Additional mount options for the container root filesystem | `list(string)` | `[]` | no |
| <a name="input_mount_points"></a> [mount\_points](#input\_mount\_points) | Optional additional volumes mounted inside the container | <pre>list(object({<br/>    path          = string<br/>    volume        = string<br/>    size          = optional(string)<br/>    mount_options = optional(list(string), [])<br/>  }))</pre> | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Hostname and name for the container | `string` | n/a | yes |
| <a name="input_nesting"></a> [nesting](#input\_nesting) | Enable LXC nesting for workloads that require nested containers | `bool` | `false` | no |
| <a name="input_networks"></a> [networks](#input\_networks) | One entry per NIC (eth0, eth1, ...). ip is CIDR or "dhcp". | <pre>list(object({<br/>    bridge  = string<br/>    ip      = string<br/>    gateway = optional(string)<br/>  }))</pre> | n/a | yes |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | Proxmox node on which the container is created | `string` | n/a | yes |
| <a name="input_on_boot"></a> [on\_boot](#input\_on\_boot) | Start the container automatically when the Proxmox node boots | `bool` | `true` | no |
| <a name="input_pool_id"></a> [pool\_id](#input\_pool\_id) | Proxmox resource pool for the container | `string` | n/a | yes |
| <a name="input_protection"></a> [protection](#input\_protection) | Prevent accidental deletion or destructive changes to the container | `bool` | n/a | yes |
| <a name="input_ssh_public_keys"></a> [ssh\_public\_keys](#input\_ssh\_public\_keys) | SSH public keys injected into the container | `list(string)` | n/a | yes |
| <a name="input_started"></a> [started](#input\_started) | Whether the container should be running after creation | `bool` | `true` | no |
| <a name="input_swap_mb"></a> [swap\_mb](#input\_swap\_mb) | Swap size allocated to the container in MB | `number` | `0` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Proxmox tags assigned to the container | `list(string)` | `[]` | no |
| <a name="input_template_file_id"></a> [template\_file\_id](#input\_template\_file\_id) | Proxmox LXC template file ID | `string` | n/a | yes |
| <a name="input_vm_id"></a> [vm\_id](#input\_vm\_id) | Proxmox container ID | `number` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
