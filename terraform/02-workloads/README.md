# 02-workloads

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.16.0 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.114.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_lxc"></a> [lxc](#module\_lxc) | ../modules/lxc | n/a |
| <a name="module_vm"></a> [vm](#module\_vm) | ../modules/vm | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [terraform_remote_state.platform](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_global_ssh_keys"></a> [global\_ssh\_keys](#input\_global\_ssh\_keys) | Public keys injected into every guest through cloud-init | `list(string)` | `[]` | no |
| <a name="input_lxc_guests"></a> [lxc\_guests](#input\_lxc\_guests) | Map of LXC container guest specifications keyed by host name. | <pre>map(object({<br/>    vmid          = number<br/>    pool_id       = optional(string, null)<br/>    cores         = number<br/>    memory_mb     = number<br/>    swap_mb       = optional(number, 0)<br/>    disk_gb       = number<br/>    mount_options = optional(list(string), [])<br/>    mount_points = optional(list(object({<br/>      path          = string<br/>      volume        = string<br/>      size          = optional(string)<br/>      mount_options = optional(list(string), [])<br/>    })), [])<br/>    networks = list(object({<br/>      bridge  = string<br/>      ip      = string<br/>      gateway = optional(string)<br/>    }))<br/>    dns_servers     = optional(list(string), null)<br/>    ssh_public_keys = optional(list(string), [])<br/>    # Defaults to null for dynamic fallback. If supplied should match a key for<br/>    # downloaded image or created template in the stage 01<br/>    lxc_template_key = optional(string, null)<br/>    nesting          = optional(bool, false)<br/>    protection       = optional(bool, false)<br/>    tags             = optional(list(string), [])<br/>    started          = optional(bool, true)<br/>    on_boot          = optional(bool, true)<br/><br/>  }))</pre> | <pre>{<br/>  "edge": {<br/>    "cores": 1,<br/>    "disk_gb": 4,<br/>    "memory_mb": 384,<br/>    "networks": [<br/>      {<br/>        "bridge": "vmbr0",<br/>        "gateway": "192.168.1.1",<br/>        "ip": "192.168.1.11/24"<br/>      },<br/>      {<br/>        "bridge": "dmz",<br/>        "ip": "10.10.20.2/24"<br/>      }<br/>    ],<br/>    "pool_id": "core",<br/>    "tags": [<br/>      "ingress"<br/>    ],<br/>    "vmid": 101<br/>  },<br/>  "mon": {<br/>    "cores": 2,<br/>    "disk_gb": 30,<br/>    "memory_mb": 1536,<br/>    "networks": [<br/>      {<br/>        "bridge": "infra",<br/>        "gateway": "10.10.10.1",<br/>        "ip": "10.10.10.10/24"<br/>      }<br/>    ],<br/>    "pool_id": "core",<br/>    "tags": [<br/>      "observability"<br/>    ],<br/>    "vmid": 110<br/>  },<br/>  "net": {<br/>    "cores": 1,<br/>    "disk_gb": 4,<br/>    "memory_mb": 384,<br/>    "networks": [<br/>      {<br/>        "bridge": "vmbr0",<br/>        "gateway": "192.168.1.1",<br/>        "ip": "192.168.1.10/24"<br/>      },<br/>      {<br/>        "bridge": "infra",<br/>        "ip": "10.10.10.2/24"<br/>      }<br/>    ],<br/>    "pool_id": "core",<br/>    "tags": [<br/>      "dns",<br/>      "vpn"<br/>    ],<br/>    "vmid": 100<br/>  },<br/>  "pbs": {<br/>    "cores": 1,<br/>    "disk_gb": 8,<br/>    "memory_mb": 1024,<br/>    "networks": [<br/>      {<br/>        "bridge": "infra",<br/>        "gateway": "10.10.10.1",<br/>        "ip": "10.10.10.11/24"<br/>      }<br/>    ],<br/>    "pool_id": "core",<br/>    "tags": [<br/>      "backup"<br/>    ],<br/>    "vmid": 111<br/>  }<br/>}</pre> | no |
| <a name="input_proxmox_endpoint"></a> [proxmox\_endpoint](#input\_proxmox\_endpoint) | Proxmox API endpoint | `string` | n/a | yes |
| <a name="input_proxmox_insecure"></a> [proxmox\_insecure](#input\_proxmox\_insecure) | Skip TLS certificate verification for the Proxmox API | `bool` | `false` | no |
| <a name="input_vm_guests"></a> [vm\_guests](#input\_vm\_guests) | Map of Virtual Machine guest specifications keyed by host name. | <pre>map(object({<br/>    vmid    = number<br/>    pool_id = optional(string, null)<br/>    # Defaults to null for dynamic fallback. If supplied should match a key for<br/>    # downloaded image or created template in the stage 01<br/>    image_key = optional(string, null)<br/>    cores     = number<br/>    memory_mb = number<br/>    disk_gb   = number<br/>    extra_disks = optional(list(object({<br/>      size_gb      = number<br/>      datastore_id = string<br/>    })), [])<br/>    networks = list(object({<br/>      bridge  = string<br/>      ip      = string<br/>      gateway = optional(string)<br/>    }))<br/>    dns_servers         = optional(list(string), null)<br/>    ssh_public_keys     = optional(list(string), [])<br/>    username            = optional(string, "debian")<br/>    vendor_data_file_id = optional(string, null)<br/>    tags                = optional(list(string), [])<br/>    started             = optional(bool, true)<br/>    on_boot             = optional(bool, true)<br/>  }))</pre> | <pre>{<br/>  "apps": {<br/>    "cores": 2,<br/>    "disk_gb": 40,<br/>    "memory_mb": 4096,<br/>    "networks": [<br/>      {<br/>        "bridge": "apps",<br/>        "gateway": "10.10.30.1",<br/>        "ip": "10.10.30.10/24"<br/>      }<br/>    ],<br/>    "on_boot": false,<br/>    "pool_id": "apps",<br/>    "started": false,<br/>    "tags": [<br/>      "apps"<br/>    ],<br/>    "vmid": 200<br/>  },<br/>  "identity": {<br/>    "cores": 1,<br/>    "disk_gb": 20,<br/>    "memory_mb": 1024,<br/>    "networks": [<br/>      {<br/>        "bridge": "infra",<br/>        "gateway": "10.10.10.1",<br/>        "ip": "10.10.10.20/24"<br/>      }<br/>    ],<br/>    "pool_id": "core",<br/>    "tags": [<br/>      "identity"<br/>    ],<br/>    "vmid": 120<br/>  },<br/>  "k3s-cp1": {<br/>    "cores": 2,<br/>    "disk_gb": 30,<br/>    "memory_mb": 2048,<br/>    "networks": [<br/>      {<br/>        "bridge": "k8s",<br/>        "gateway": "10.10.40.1",<br/>        "ip": "10.10.40.11/24"<br/>      }<br/>    ],<br/>    "on_boot": false,<br/>    "pool_id": "k3s",<br/>    "started": false,<br/>    "tags": [<br/>      "k3s",<br/>      "server"<br/>    ],<br/>    "vmid": 301<br/>  },<br/>  "k3s-w1": {<br/>    "cores": 2,<br/>    "disk_gb": 30,<br/>    "memory_mb": 2048,<br/>    "networks": [<br/>      {<br/>        "bridge": "k8s",<br/>        "gateway": "10.10.40.1",<br/>        "ip": "10.10.40.21/24"<br/>      }<br/>    ],<br/>    "on_boot": false,<br/>    "pool_id": "k3s",<br/>    "started": false,<br/>    "tags": [<br/>      "k3s",<br/>      "agent"<br/>    ],<br/>    "vmid": 302<br/>  },<br/>  "k3s-w2": {<br/>    "cores": 2,<br/>    "disk_gb": 30,<br/>    "memory_mb": 2048,<br/>    "networks": [<br/>      {<br/>        "bridge": "k8s",<br/>        "gateway": "10.10.40.1",<br/>        "ip": "10.10.40.22/24"<br/>      }<br/>    ],<br/>    "on_boot": false,<br/>    "pool_id": "k3s",<br/>    "started": false,<br/>    "tags": [<br/>      "k3s",<br/>      "agent"<br/>    ],<br/>    "vmid": 303<br/>  }<br/>}</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_global_ssh_keys"></a> [global\_ssh\_keys](#output\_global\_ssh\_keys) | List of global SSH public keys injected into all guests |
| <a name="output_inventory"></a> [inventory](#output\_inventory) | Guests with vmid, type, pool and IPs (no CIDR) |
| <a name="output_public_ssh_keys"></a> [public\_ssh\_keys](#output\_public\_ssh\_keys) | Map of resolved SSH public keys injected into each guest |
<!-- END_TF_DOCS -->
