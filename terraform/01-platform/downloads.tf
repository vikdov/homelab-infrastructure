# ---------------------------------------------------------------------------
# OS artifacts
# ---------------------------------------------------------------------------
#
# This file manages the operating-system artifacts consumed by the platform.
#
# There are two different artifact types:
#
#   vm_images      -> cloud images used to build Proxmox VM templates
#   lxc_templates  -> Proxmox LXC template archives used directly by containers
#
# Guests reference these artifacts by logical keys such as "debian13".
# The guest definition therefore does not need to know the download URL,
# datastore, or Proxmox content type.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# VM images
# ---------------------------------------------------------------------------
#
# Download each configured VM image once.
#
# The map key (for example "debian13") is the stable logical identifier used
# elsewhere in Terraform. The URL and filename describe the actual upstream
# artifact.
#
# "import" is used because these files are imported into Proxmox as VM disk
# images rather than stored as LXC templates.
# ---------------------------------------------------------------------------

# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/download_file

resource "proxmox_download_file" "downloaded_vm_images" {
  for_each = var.vm_images != null ? var.vm_images : {}

  node_name    = var.node_name
  datastore_id = var.file_datastore
  content_type = "import"

  url                = each.value.download_url
  file_name          = coalesce(each.value.file_name, basename(each.value.download_url))
  checksum           = each.value.checksum != null ? each.value.checksum : null
  checksum_algorithm = each.value.checksum != null ? each.value.checksum_algorithm : null
}

# ---------------------------------------------------------------------------
# LXC templates
# ---------------------------------------------------------------------------
#
# Download each configured LXC template once.
#
# Unlike VM images, these are consumed directly by LXC containers, so the
# Proxmox content type must be "vztmpl".
# ---------------------------------------------------------------------------

resource "proxmox_download_file" "downloaded_lxc_templates" {
  for_each = var.lxc_templates != null ? var.lxc_templates : {}

  node_name    = var.node_name
  datastore_id = var.file_datastore
  content_type = "vztmpl"

  url                = each.value.download_url
  file_name          = coalesce(each.value.file_name, basename(each.value.download_url))
  checksum           = each.value.checksum != null ? each.value.checksum : null
  checksum_algorithm = each.value.checksum != null ? each.value.checksum_algorithm : null
}
