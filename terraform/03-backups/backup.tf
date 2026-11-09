# ---------------------------------------------------------------------------
# Proxmox backups to PBS
# ---------------------------------------------------------------------------
#
# Terraform owns the PVE side only:
#   1. the PBS storage entry (connection + credentials)
#   2. the vzdump job (what, when, how)
#
# Ansible owns the PBS side: install, datastore, users/tokens, prune, garbage
# collection, verification, and the off-box sync job.
#
# Retention lives on PBS, not here. The PVE token only has DatastoreBackup, so
# a compromised PVE host can create backups but cannot prune or delete them.
# The job therefore sets keep-all explicitly; PBS prune jobs trim the datastore.
#
# Secrets: the PBS token secret (and the optional encryption key) end up in the Terraform state.
# Keep the state in an encrypted, access-controlled backend; a local state file is plaintext.
# ---------------------------------------------------------------------------

locals {
  workloads = data.terraform_remote_state.workloads.outputs
  inventory = local.workloads.inventory
  node_name = local.workloads.node_name

  # PVE wants a bare address; stage 02 may store IPs as CIDR ("10.0.0.5/24").
  pbs_server = var.pbs_server != null ? var.pbs_server : try(split("/", local.inventory[var.pbs_guest].ips[0])[0], null)

  # Backup selection is derived from stage 02, so new guests in a selected pool
  # are picked up automatically.
  backup_vmids = sort([
    for name, g in local.inventory : tostring(g.vmid)
    if g.pool != null && contains(var.backup_pools, g.pool) && !contains(var.backup_exclude_guests, name)
  ])
}

# Fail at plan time instead of creating a job that backs up nothing, or PBS itself.
resource "terraform_data" "backup_checks" {
  lifecycle {
    precondition {
      condition     = local.pbs_server != null
      error_message = "No PBS address: '${var.pbs_guest}' has no static IP in stage 02 inventory and pbs_server is not set."
    }

    precondition {
      condition     = length(local.backup_vmids) > 0
      error_message = "No guests match backup_pools after exclusions; the backup job would be empty."
    }

    precondition {
      condition     = !contains(local.backup_vmids, try(tostring(local.inventory[var.pbs_guest].vmid), "-"))
      error_message = "The PBS guest '${var.pbs_guest}' is in the backup set. Add it to backup_exclude_guests."
    }

    precondition {
      condition     = alltrue([for n in var.backup_exclude_guests : contains(keys(local.inventory), n)])
      error_message = "backup_exclude_guests contains a name that is not a guest in stage 02."
    }
  }
}

# https://registry.terraform.io/providers/bpg/proxmox/latest/docs
# (verify the resource name for your provider version)
resource "proxmox_storage_pbs" "this" {
  id      = var.storage_id
  nodes   = [local.node_name]
  content = ["backup"]

  server      = local.pbs_server
  datastore   = var.pbs_datastore
  username    = var.pbs_username
  password    = var.pbs_token_secret
  fingerprint = var.pbs_fingerprint
  namespace   = var.pbs_namespace

  encryption_key = var.pbs_encryption_key

  depends_on = [terraform_data.backup_checks]
}

resource "proxmox_backup_job" "this" {
  id      = "daily-core"
  enabled = var.backup_enabled

  node     = local.node_name
  storage  = proxmox_storage_pbs.this.id
  schedule = var.backup_schedule
  vmid     = local.backup_vmids
  mode     = var.backup_mode

  # Run at the next opportunity if the node was off at the scheduled time.
  repeat_missed  = true
  notes_template = "{{guestname}} ({{vmid}})"
  comment        = "Managed by Terraform stage 03; retention is enforced on PBS"

  # Failures go through the PVE notification system (Datacenter > Notifications). Make sure a
  # target and matcher exist there, or a failed backup is only visible in the task log.
  notification_mode = var.backup_notification_mode

  # Retention is enforced on PBS (Ansible). See header.
  prune_backups = {
    "keep-all" = "1"
  }
}
