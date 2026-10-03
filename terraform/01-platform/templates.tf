# ---------------------------------------------------------------------------
# VM templates
# ---------------------------------------------------------------------------
#
# Build reusable Proxmox VM templates from the VM cloud images defined in
# var.vm_images.
#
# Template selection:
#
#   template_vm_id_map = {}
#       -> create a template for every VM image in var.vm_images
#
#   template_vm_id_map = {
#     debian13 = 9000
#   }
#       -> create only the debian13 template with VM ID 9000
#
# The upstream cloud image is downloaded by downloads.tf and then imported
# into the template as its boot disk.
#
# Cloud-init user data is a snippet uploaded by 00-bootstrap and referenced
# below. It installs and starts the QEMU guest agent during the first boot of
# every VM cloned from the template.
#
# The snippet is a bootstrap-stage dependency; this stage only references it
# and does not create or modify it.
# ---------------------------------------------------------------------------
locals {
  # If template_vm_id_map is empty, create templates for every downloaded VM image.
  #
  # If template_vm_id_map is populated, create templates only for the
  # explicitly selected images.
  template_images = length(var.template_vm_id_map) == 0 ? var.vm_images : {
    for image_name, vm_id in var.template_vm_id_map :
    image_name => var.vm_images[image_name]
  }
}

# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm
resource "proxmox_virtual_environment_vm" "template" {
  for_each = local.template_images

  name      = "tpl-${each.key}"
  node_name = var.node_name

  # Use explicit map value if provided; otherwise auto-calculate starting at 9000
  vm_id = try(
    var.template_vm_id_map[each.key],
    9000 + index(keys(local.template_images), each.key)
  )


  template = true
  started  = false

  agent {
    enabled = true
  }


  tags = [
    "template",
    "os-${each.key}",
  ]

  operating_system {
    type = "l26"
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 1024
  }

  scsi_hardware = "virtio-scsi-single"

  # Boot disk
  # Import the cloud image downloaded by downloads.tf.
  # The download resource is indexed using the same logical key as
  # local.template_images.
  # -------------------------------------------------------------------------

  disk {
    datastore_id = var.vm_datastore

    import_from = proxmox_download_file.downloaded_vm_images[each.key].id

    interface = "scsi0"
    discard   = "on"
    iothread  = true
    ssd       = true
  }

  network_device {
    bridge = var.template_bridge
  }

  serial_device {}

  vga {
    type = "serial0"
  }

  initialization {
    datastore_id = var.vm_datastore

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    # Snippet is created in 00-bootstrap (SSH/root); it must exist before
    # this stage is applied. ID format: <datastore>:snippets/<file_name>
    user_data_file_id = "${var.file_datastore}:snippets/${var.template_user_data_file_name}"
  }
}
