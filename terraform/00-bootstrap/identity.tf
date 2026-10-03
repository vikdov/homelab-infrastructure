# ---------------------------------------------------------------------------
# Resource Pools
# Organizational containers that group VMs, LXC containers, and storage.
# Useful for:
#   - Logical organization in the Proxmox UI
#   - Fine-grained permissions / multi-tenancy (ACL on the pool)
#   - Scoping backup jobs and bulk operations
# Docs:
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_pool
# ---------------------------------------------------------------------------
resource "proxmox_virtual_environment_pool" "this" {
  for_each = var.pools
  pool_id  = each.key
  comment  = each.value
}
# ---------------------------------------------------------------------------
# Terraform role
# ---------------------------------------------------------------------------
#
# Dedicated Proxmox role used by the Terraform service account. Least privileges
#
# Note:
# - Proxmox privileges may change between versions.
# - Verify this list after Proxmox upgrades (e.g. PVE 9 removed VM.Monitor).
#
# Docs:
# https://pve.proxmox.com/pve-docs/chapter-pveum.html
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_role

resource "proxmox_virtual_environment_role" "terraform" {
  role_id = "TerraformProvisioner"

  privileges = [
    # Datastore & Storage
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.AllocateTemplate",
    "Datastore.Audit",
    # Hardware Mappings & SDN
    "Mapping.Audit",
    "Mapping.Use",
    "Pool.Allocate",
    "Pool.Audit",
    "SDN.Allocate",
    "SDN.Audit",
    "SDN.Use",
    # System & Consoles
    "Sys.Audit",
    "Sys.Console",
    "Sys.Modify", # required for proxmox_download_file
    # VM Lifecycle & Config
    "VM.Allocate",
    "VM.Audit",
    "VM.Backup",
    "VM.Clone",
    "VM.Config.CDROM",
    "VM.Config.Cloudinit",
    "VM.Config.CPU",
    "VM.Config.Disk",
    "VM.Config.HWType",
    "VM.Config.Memory",
    "VM.Config.Network",
    "VM.Config.Options",
    "VM.Console",
    "VM.GuestAgent.Audit",
    "VM.Migrate",
    "VM.PowerMgmt",
    "VM.Replicate",
    "VM.Snapshot",
    "VM.Snapshot.Rollback"
  ]
}
# ---------------------------------------------------------------------------
# Service accounts
# ---------------------------------------------------------------------------
#
# Each entry represents a separate Proxmox service account and defines:
# - the account description
# - the role assigned to the account
# - the ACL path where the role is applied
#
# The built-in Terraform account is always present. Additional accounts can
# be supplied through var.extra_service_accounts.
#
# merge() combines the built-in accounts with user-provided accounts.
#
locals {
  service_accounts = merge(
    {
      terraform = {
        comment = "Terraform platform stage"
        role_id = proxmox_virtual_environment_role.terraform.role_id
        path    = "/"
      }
    },
    var.extra_service_accounts
  )
}

# ---------------------------------------------------------------------------
# Proxmox users
# ---------------------------------------------------------------------------
#
# Service accounts are created without passwords and are intended to use
# API tokens for authentication.
#
# for_each creates one Proxmox user for every service account defined above.
#
# Docs:
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_user
#
resource "proxmox_virtual_environment_user" "this" {
  for_each = local.service_accounts

  user_id = "${each.key}@pve"
  comment = "${each.value.comment} - managed by Terraform"
  enabled = true
}

# ---------------------------------------------------------------------------
# API tokens
# ---------------------------------------------------------------------------
#
# Each service account receives an API token named "api".
#
# privileges_separation = false means the token uses the same ACLs as its
# parent user. This lets manage permissions with a single ACL per account.
#
# Docs:
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/user_token
#
resource "proxmox_user_token" "this" {
  for_each = local.service_accounts

  user_id               = proxmox_virtual_environment_user.this[each.key].user_id
  token_name            = "api"
  comment               = "API token for ${each.key}"
  privileges_separation = false
}

# ---------------------------------------------------------------------------
# Access control
# ---------------------------------------------------------------------------
#
# Assign the configured role to each service account at its configured path.
#
# propagate = true makes the permission apply to child objects below the
# specified path.
#
# Docs:
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/acl
#
resource "proxmox_acl" "this" {
  for_each = local.service_accounts

  user_id   = proxmox_virtual_environment_user.this[each.key].user_id
  role_id   = each.value.role_id
  path      = each.value.path
  propagate = true
}
