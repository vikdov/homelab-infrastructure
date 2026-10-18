# ---------------------------------------------------------------------------
# Guest Orchestration (LXC & VMs)
# ---------------------------------------------------------------------------
# Consumes remote state outputs from Stage 01 (Platform) to dynamically
# resolve templates, images, and networking constraints before provisioning.
# ---------------------------------------------------------------------------
locals {
  platform               = data.terraform_remote_state.platform.outputs
  node_name              = local.platform.node_name
  file_datastore         = local.platform.file_datastore
  vm_datastore           = local.platform.vm_datastore
  dns_servers            = local.platform.dns_servers
  default_vendor_data_id = "${local.file_datastore}:snippets/template-qemu-guest-agent.yaml"
  # -------------------------------------------------------------------------
  # LXC Template Resolution & Smart Fallback
  # -------------------------------------------------------------------------
  lxc_template_keys  = keys(try(local.platform.downloaded_lxc_templates, {}))
  first_lxc_template = length(local.lxc_template_keys) > 0 ? local.lxc_template_keys[0] : null

  # Resolve each lxc_guest's template key: use supplied override or fall back gracefully to first available
  resolved_lxc_guests = {
    for name, config in var.lxc_guests : name => merge(config, {
      resolved_template_key = config.lxc_template_key != null ? config.lxc_template_key : local.first_lxc_template
    })
  }
  # Resolve final list of SSH keys for each lxc_guest
  resolved_lxc_guest_ssh_keys = {
    for name, config in var.lxc_guests : name => distinct(concat(var.global_ssh_keys, config.ssh_public_keys))
  }

  # -------------------------------------------------------------------------
  # VM Image Resolution & Smart Fallback (Template-First Priority)
  # -------------------------------------------------------------------------
  vm_template_keys         = keys(try(local.platform.vm_templates, {}))
  downloaded_vm_image_keys = keys(try(local.platform.downloaded_vm_images, {}))
  all_available_vm_keys    = distinct(concat(local.vm_template_keys, local.downloaded_vm_image_keys))

  # Default fallback if guest specifies no image: pick the first available template
  first_vm_source_key = length(local.vm_template_keys) > 0 ? local.vm_template_keys[0] : (
    length(local.downloaded_vm_image_keys) > 0 ? local.downloaded_vm_image_keys[0] : null
  )

  # Resolve each vm_guest's image key based on your exact rules:
  # 1. If config.image_key is provided, use it.
  # 2. Otherwise, fall back to the first available template (or image).
  resolved_vm_guests = {
    for name, config in var.vm_guests : name => merge(config, {
      resolved_image_key = config.image_key != null ? config.image_key : local.first_vm_source_key
    })
  }

  # Split resolution into template_vm_id (template-first lookup) vs image_file_id
  resolved_vm_images = {
    for name, config in var.vm_guests : name => {
      # Check if the resolved key exists in vm_templates first
      template_vm_id = try(local.platform.vm_templates[local.resolved_vm_guests[name].resolved_image_key].vm_id, null)

      # If it's NOT a template, check if it exists in downloaded_vm_images as a file ID
      image_file_id = try(local.platform.vm_templates[local.resolved_vm_guests[name].resolved_image_key].vm_id, null) == null ? try(local.platform.downloaded_vm_images[local.resolved_vm_guests[name].resolved_image_key].id, null) : null
    }
  }
  # Resolve final list of SSH keys for each vm_guest
  resolved_vm_guest_ssh_keys = {
    for name, config in var.vm_guests : name => distinct(concat(var.global_ssh_keys, config.ssh_public_keys))
  }

  # Global ID collection for collision detection across both resource types
  lxc_vmids = [for k, v in var.lxc_guests : v.vmid]
  vm_vmids  = [for k, v in var.vm_guests : v.vmid]
  all_vmids = concat(local.lxc_vmids, local.vm_vmids)
}
# ---------------------------------------------------------------------------
# Validation Guards (Fail-Fast Assertion Blocks)
# ---------------------------------------------------------------------------
resource "terraform_data" "guest_checks" {
  lifecycle {
    precondition {
      condition     = length(var.lxc_guests) == 0 || length(local.lxc_template_keys) > 0
      error_message = "LXC guests are defined, but stage 01 exports no lxc_templates. Apply stage 01 first."
    }
    precondition {
      condition = alltrue([
        for g in values(local.resolved_lxc_guests) :
        g.resolved_template_key != null && contains(local.lxc_template_keys, g.resolved_template_key)
      ])
      error_message = "An lxc_template_key (or the fallback) does not exist in stage 01 downloaded_lxc_templates."
    }
    precondition {
      condition     = length(var.vm_guests) == 0 || length(local.all_available_vm_keys) > 0
      error_message = "VM guests are defined, but stage 01 exports no vm_templates or downloaded_vm_images."
    }
    precondition {
      condition = alltrue([
        for g in values(local.resolved_vm_guests) :
        g.resolved_image_key != null && contains(local.all_available_vm_keys, g.resolved_image_key)
      ])
      error_message = "An image_key (or the fallback) does not exist in stage 01 outputs."
    }
    precondition {
      condition = (
        length(local.all_vmids) == length(distinct(local.all_vmids)) &&
        alltrue([for id in local.all_vmids : id >= 100 && id <= 9999])
      )
      error_message = "VMID collision or out of range. LXC and VM IDs must be globally unique and between 100 and 9999."
    }
  }
}

# ---------------------------------------------------------------------------
# Module Instantiation
# ---------------------------------------------------------------------------
module "lxc" {
  source   = "../modules/lxc"
  for_each = coalesce(var.lxc_guests, {})

  name             = each.key
  vm_id            = each.value.vmid
  node_name        = local.node_name
  pool_id          = each.value.pool_id
  cores            = each.value.cores
  memory_mb        = each.value.memory_mb
  swap_mb          = each.value.swap_mb
  disk_gb          = each.value.disk_gb
  datastore_id     = local.vm_datastore
  mount_options    = each.value.mount_options
  mount_points     = each.value.mount_points
  networks         = each.value.networks
  dns_servers      = each.value.dns_servers == null ? local.dns_servers : each.value.dns_servers
  ssh_public_keys  = local.resolved_lxc_guest_ssh_keys[each.key]
  template_file_id = local.platform.downloaded_lxc_templates[local.resolved_lxc_guests[each.key].resolved_template_key].id
  nesting          = each.value.nesting
  protection       = each.value.protection
  tags             = concat(["iac"], each.value.tags)
  started          = each.value.started
  on_boot          = each.value.on_boot
}

module "vm" {
  source   = "../modules/vm"
  for_each = coalesce(var.vm_guests, {})

  name            = each.key
  vm_id           = each.value.vmid
  node_name       = local.node_name
  pool_id         = each.value.pool_id
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
  ssh_public_keys = local.resolved_vm_guest_ssh_keys[each.key]
  vendor_data_file_id = coalesce(
    each.value.vendor_data_file_id,
    local.default_vendor_data_id
  )
  tags    = concat(["iac"], each.value.tags)
  started = each.value.started
  on_boot = each.value.on_boot
}
