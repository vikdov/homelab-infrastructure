locals {
  platform               = data.terraform_remote_state.platform.outputs
  node_name              = local.platform.node_name
  file_datastore         = local.platform.file_datastore
  vm_datastore           = local.platform.vm_datastore
  dns_servers            = local.platform.dns_servers
  default_vendor_data_id = "${local.file_datastore}:snippets/template-qemu-guest-agent.yaml"
  # Separate or combined key resolution for LXC and VMs
  resolved_lxc_guest_keys = {
    for name, config in var.lxc_guests : name => distinct(concat(var.global_ssh_keys, config.ssh_public_keys))
  }
  # Check 1: Try to fetch template VM ID from platform state outputs
  # Safely try both maps independently so missing keys don't crash the plan before checks run
  resolved_vm_images = {
    for name, config in var.vm_guests : name => {
      template_vm_id = try(local.platform.vm_templates[config.image_key].vm_id, null)
      image_file_id  = try(local.platform.downloaded_vm_images[config.image_key].id, null)
    }
  }
  resolved_vm_guest_keys = {
    for name, config in var.vm_guests : name => distinct(concat(var.global_ssh_keys, config.ssh_public_keys))
  }
  # Check: Image & template ID resolution for VMs
  lxc_vmids = [for k, v in var.lxc_guests : v.vmid]
  vm_vmids  = [for k, v in var.vm_guests : v.vmid]
  all_vmids = concat(local.lxc_vmids, local.vm_vmids)
}

check "proxmox_vmid_validation" {
  assert {
    condition = (
      length(local.all_vmids) == length(distinct(local.all_vmids)) &&
      alltrue([for id in local.all_vmids : id >= 100 && id <= 9999])
    )
    error_message = "Proxmox VMID collision detected or invalid range! All LXC and VM IDs must be globally unique and fall between 100 and 9999."
  }
}

check "proxmox_image_validation" {
  assert {
    condition = alltrue([
      for name, config in var.vm_guests :
      contains(keys(local.platform.vm_templates), config.image_key) ||
      contains(keys(local.platform.downloaded_vm_images), config.image_key)
    ])
    error_message = "Invalid image_key detected! The specified image must exist in either vm_templates or downloaded_vm_images from the platform state."
  }
}

module "lxc" {
  source   = "../modules/lxc"
  for_each = coalesce(var.lxc_guests, {})

  name            = each.key
  vm_id           = each.value.vmid
  node_name       = local.node_name
  pool_id         = each.value.pool_id
  cores           = each.value.cores
  memory_mb       = each.value.memory_mb
  swap_mb         = each.value.swap_mb
  disk_gb         = each.value.disk_gb
  datastore_id    = local.vm_datastore
  mount_options   = each.value.mount_options
  mount_points    = each.value.mount_points
  networks        = each.value.networks
  dns_servers     = each.value.dns_servers == null ? local.dns_servers : each.value.dns_servers
  ssh_public_keys = local.resolved_lxc_guest_keys[each.key]
  # Dynamic resolution from platform remote state outputs
  template_file_id = local.platform.lxc_templates[each.value.lxc_template_key].id
  nesting          = each.value.nesting
  protection       = each.value.protection
  tags             = each.value.tags
  started          = each.value.started
  on_boot          = each.value.on_boot
}

module "vm" {
  source   = "../modules/vm"
  for_each = var.vm_guests

  name      = each.key
  vm_id     = each.value.vmid
  node_name = local.node_name
  pool_id   = each.value.pool_id
  # Clean references to local lookup map
  template_vm_id  = local.resolved_vm_images[each.key].template_vm_id
  image_file_id   = local.resolved_vm_images[each.key].image_file_id
  cores           = each.value.cores
  memory_mb       = each.value.memory_mb
  disk_gb         = each.value.disk_gb
  datastore_id    = local.vm_datastore
  extra_disks     = each.value.extra_disks
  networks        = each.value.networks
  dns_servers     = each.value.dns_servers == null ? local.dns_servers : each.value.dns_servers
  username        = each.value.username
  ssh_public_keys = local.resolved_vm_guest_keys[each.key]
  # Fallback to the convention snippet if no guest-specific override is provided
  vendor_data_file_id = coalesce(
    each.value.vendor_data_file_id,
    local.default_vendor_data_id
  )
  tags    = each.value.tags
  started = each.value.started
  on_boot = each.value.on_boot
}
