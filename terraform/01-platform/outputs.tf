# ---------------------------------------------------------------------------
# Platform Outputs
# ---------------------------------------------------------------------------
#
# Expose core platform infrastructure details so that subsequent Terraform
# stages (such as workload and VM deployments) can consume them without
# hardcoding names, IDs, or network parameters.
# ---------------------------------------------------------------------------

output "node_name" {
  description = "The Proxmox target node name used across platform resources."
  value       = var.node_name
}

output "file_datastore" {
  description = "The datastore used for ISOs, LXC templates, and cloud-init snippets."
  value       = var.file_datastore
}

output "vm_datastore" {
  description = "The datastore used for VM and container root disks."
  value       = var.vm_datastore
}

# ---------------------------------------------------------------------------
# SDN
# ---------------------------------------------------------------------------

output "dns_servers" {
  description = "List of DNS servers used for created guests"
  value       = var.dns_servers
}

output "vnets" {
  description = "Map of created VNets and their properties, consumable by workload stages."
  value = {
    for k, v in proxmox_sdn_vnet.this : k => {
      id      = v.id
      alias   = v.alias
      zone    = v.zone
      gateway = var.vnets[k].gateway
      cidr    = var.vnets[k].cidr
    }
  }
}

# ---------------------------------------------------------------------------
# VM OS Images
# ---------------------------------------------------------------------------
#
# These are platform-level artifacts.
#
# Downstream workload stages should normally consume vm_templates instead of
# these images directly.
# ---------------------------------------------------------------------------

output "downloaded_vm_images" {
  description = "VM OS images downloaded and managed by the platform stage."

  value = {
    for key, image in proxmox_download_file.downloaded_vm_images :
    key => {
      id           = image.id
      datastore_id = image.datastore_id
    }
  }
}


# ---------------------------------------------------------------------------
# LXC Templates
# ---------------------------------------------------------------------------
#
# LXC template archives downloaded and managed by the platform stage.
# ---------------------------------------------------------------------------

output "downloaded_lxc_templates" {
  description = "LXC template archives downloaded and managed by the platform stage."

  value = {
    for key, template in proxmox_download_file.downloaded_lxc_templates :
    key => {
      id           = template.id
      datastore_id = template.datastore_id
    }
  }
}


# ---------------------------------------------------------------------------
# VM Templates
# ---------------------------------------------------------------------------
#
# Reusable Proxmox VM templates created from the downloaded VM OS images.
#
# This is the primary VM-template interface exposed to downstream stages.
#
# Example:
#
#   data.terraform_remote_state.platform.outputs.vm_templates["debian13"].id
#
# ---------------------------------------------------------------------------

output "vm_templates" {
  description = "VM templates created by the platform stage, keyed by logical OS image name."

  value = {
    for key, vm in proxmox_virtual_environment_vm.template :
    key => {
      vm_id     = vm.vm_id
      name      = vm.name
      node_name = vm.node_name
    }
  }
}
