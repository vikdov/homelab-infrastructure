# Docs:
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_container
resource "proxmox_virtual_environment_container" "this" {
  description = "Managed by Terraform ${var.name} Server"
  node_name   = var.node_name
  vm_id       = var.vm_id
  pool_id     = var.pool_id
  tags        = sort(var.tags)
  #  unprivileged mode is hardcoded for security best practices.
  unprivileged  = true
  started       = var.started
  start_on_boot = var.on_boot
  protection    = var.protection

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory_mb
    swap      = var.swap_mb
  }

  # Root filesystem for the container.
  disk {
    datastore_id  = var.datastore_id
    size          = var.disk_gb
    mount_options = var.mount_options
  }

  dynamic "mount_point" {
    for_each = var.mount_points != null ? var.mount_points : []

    content {
      path          = mount_point.value.path
      volume        = mount_point.value.volume
      size          = mount_point.value.size
      mount_options = mount_point.value.mount_options
      replicate     = false
    }
  }

  operating_system {
    template_file_id = var.template_file_id
    type             = "debian"
  }

  dynamic "network_interface" {
    for_each = var.networks
    content {
      # Array positioning generates eth0, eth1, etc., matching the ip_config list index.
      name   = "eth${network_interface.key}"
      bridge = network_interface.value.bridge
    }
  }

  # Enable nesting only for workloads that explicitly require it.
  dynamic "features" {
    for_each = var.nesting ? [1] : []
    content {
      nesting = true
    }
  }

  initialization {
    hostname = var.name

    dynamic "ip_config" {
      for_each = var.networks
      content {
        ipv4 {
          address = ip_config.value.ip
          # Proxmox API requires gateway to be null/omitted when address is "dhcp"
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
      keys = var.ssh_public_keys
    }
  }

  # Terraform waits until the container has an IPv4 address before
  # considering creation complete. Prevents race conditions during
  # post-provisioning runs (e.g., Ansible).
  wait_for_ip {
    ipv4 = true
    ipv6 = false
  }
}
