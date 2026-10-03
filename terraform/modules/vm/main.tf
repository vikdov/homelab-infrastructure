# Docs:
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm
resource "proxmox_virtual_environment_vm" "this" {
  description = "Managed by Terraform ${var.name} Server"
  name        = var.name
  node_name   = var.node_name
  vm_id       = var.vm_id
  pool_id     = var.pool_id
  tags        = sort(var.tags)
  started     = var.started
  on_boot     = var.on_boot

  # 1. DYNAMIC CLONE: Only rendered if var.template_vm_id is provided (not null)
  dynamic "clone" {
    for_each = var.template_vm_id != null ? [1] : []

    content {
      vm_id        = var.template_vm_id
      datastore_id = var.datastore_id
      full         = true
    }
  }

  # QEMU guest agent allows Proxmox/provider operations to obtain guest
  # information such as the VM's IP address.
  agent {
    enabled = true
    wait_for_ip {
      ipv4 = true
    }
  }

  cpu {
    cores = var.cores

    # Expose the host CPU to the guest. This is appropriate for this
    # single-node homelab but reduces live-migration portability.
    type = "host"
  }

  memory {
    dedicated = var.memory_mb
  }

  scsi_hardware = "virtio-scsi-single"

  # Boot disk: matches the template's scsi0 and grows it to disk_gb.
  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_gb
    discard      = "on"
    iothread     = true
    ssd          = true
    # 2. CONDITIONAL IMPORT: If cloning from a template, import_from MUST be null.
    #    If NOT cloning, import_from uses var.image_file_id.
    import_from = var.template_vm_id == null ? var.image_file_id : null
  }

  # Additional disks start at scsi1 because scsi0 is reserved for the
  # boot disk defined above.
  dynamic "disk" {
    for_each = var.extra_disks

    content {
      datastore_id = disk.value.datastore_id
      interface    = "scsi${disk.key + 1}"
      size         = disk.value.size_gb
      file_format  = "raw"
      discard      = "on"
      iothread     = true
    }
  }

  dynamic "network_device" {
    for_each = var.networks

    content {
      bridge = network_device.value.bridge
    }
  }

  initialization {
    # Cloud-init data is stored on the specified datastore.
    datastore_id        = var.datastore_id
    vendor_data_file_id = var.vendor_data_file_id

    dynamic "ip_config" {
      for_each = var.networks

      content {
        ipv4 {
          address = ip_config.value.ip
          gateway = ip_config.value.ip == "dhcp" ? null : ip_config.value.gateway
        }
      }
    }

    dynamic "dns" {
      for_each = length(var.dns_servers) > 0 ? [1] : []

      content {
        servers = var.dns_servers
      }
    }

    user_account {
      username = var.username
      keys     = var.ssh_public_keys
    }
  }
}
