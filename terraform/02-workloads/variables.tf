# Provider
variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS certificate verification for the Proxmox API"
  type        = bool
  default     = false
}

# Guest Provisioning & Access Controls
variable "global_ssh_keys" {
  description = "Public keys injected into every guest through cloud-init"
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Guest inventory
# ---------------------------------------------------------------------------
#
# Guests are declared as typed maps and materialized through the VM and LXC
# modules below. This keeps the root configuration focused on orchestration
# while the modules own the Proxmox resource details.
#
# Environment-specific values can be overridden in *.tfvars files.
# The defaults below describe this homelab's current topology.
# ---------------------------------------------------------------------------
variable "lxc_guests" {
  description = "Map of LXC container guest specifications keyed by host name."
  type = map(object({
    vmid          = number
    pool_id       = optional(string, null)
    cores         = number
    memory_mb     = number
    swap_mb       = optional(number, 0)
    disk_gb       = number
    mount_options = optional(list(string), [])
    mount_points = optional(list(object({
      path          = string
      volume        = string
      size          = optional(string)
      mount_options = optional(list(string), [])
    })), [])
    networks = list(object({
      bridge  = string
      ip      = string
      gateway = optional(string)
    }))
    dns_servers     = optional(list(string), null)
    ssh_public_keys = optional(list(string), [])
    # Defaults to null for dynamic fallback. If supplied should match a key for
    # downloaded image or created template in the stage 01
    lxc_template_key = optional(string, null)
    nesting          = optional(bool, false)
    protection       = optional(bool, false)
    tags             = optional(list(string), [])
    started          = optional(bool, true)
    on_boot          = optional(bool, true)

  }))

  default = {
    net = {
      vmid      = 100
      pool_id   = "core"
      cores     = 1
      memory_mb = 384
      disk_gb   = 4
      networks = [
        { bridge = "vmbr0", ip = "192.168.1.10/24", gateway = "192.168.1.1" }, # LAN (default route)
        { bridge = "infra", ip = "10.10.10.2/24" }
      ]
      tags = ["dns", "vpn"]
    }
    edge = {
      vmid      = 101
      pool_id   = "core"
      cores     = 1
      memory_mb = 384
      disk_gb   = 4
      networks = [
        { bridge = "vmbr0", ip = "192.168.1.11/24", gateway = "192.168.1.1" },
        { bridge = "dmz", ip = "10.10.20.2/24" }
      ]
      tags = ["ingress"]
    }
    mon = {
      vmid      = 110
      pool_id   = "core"
      cores     = 2
      memory_mb = 1536
      disk_gb   = 30
      networks = [
        { bridge = "infra", ip = "10.10.10.10/24", gateway = "10.10.10.1" }
      ]
      tags = ["observability"]
    }
    pbs = {
      vmid      = 111
      pool_id   = "core"
      cores     = 1
      memory_mb = 1024
      disk_gb   = 8
      networks = [
        { bridge = "infra", ip = "10.10.10.11/24", gateway = "10.10.10.1" }
      ]
      tags = ["backup"]
    }
  }
}
variable "vm_guests" {
  description = "Map of Virtual Machine guest specifications keyed by host name."
  type = map(object({
    vmid    = number
    pool_id = optional(string, null)
    # Defaults to null for dynamic fallback. If supplied should match a key for
    # downloaded image or created template in the stage 01
    image_key = optional(string, null)
    cores     = number
    memory_mb = number
    disk_gb   = number
    extra_disks = optional(list(object({
      size_gb      = number
      datastore_id = string
    })), [])
    networks = list(object({
      bridge  = string
      ip      = string
      gateway = optional(string)
    }))
    dns_servers         = optional(list(string), null)
    ssh_public_keys     = optional(list(string), [])
    username            = optional(string, "debian")
    vendor_data_file_id = optional(string, null)
    tags                = optional(list(string), [])
    started             = optional(bool, true)
    on_boot             = optional(bool, true)
  }))

  default = {
    identity = {
      vmid      = 120
      pool_id   = "core"
      cores     = 1
      memory_mb = 1024
      disk_gb   = 20
      networks = [
        { bridge = "infra", ip = "10.10.10.20/24", gateway = "10.10.10.1" }
      ]
      tags = ["identity"]
    }
    apps = {
      vmid      = 200
      pool_id   = "apps"
      cores     = 2
      memory_mb = 4096
      disk_gb   = 40
      networks = [
        { bridge = "apps", ip = "10.10.30.10/24", gateway = "10.10.30.1" }
      ]
      tags    = ["apps"]
      started = false
      on_boot = false
    }
    "k3s-cp1" = {
      vmid      = 301
      pool_id   = "k3s"
      cores     = 2
      memory_mb = 2048
      disk_gb   = 30
      networks = [
        { bridge = "k8s", ip = "10.10.40.11/24", gateway = "10.10.40.1" }
      ]
      tags    = ["k3s", "server"]
      started = false
      on_boot = false
    }
    "k3s-w1" = {
      vmid      = 302
      pool_id   = "k3s"
      cores     = 2
      memory_mb = 2048
      disk_gb   = 30
      networks = [
        { bridge = "k8s", ip = "10.10.40.21/24", gateway = "10.10.40.1" }
      ]
      tags    = ["k3s", "agent"]
      started = false
      on_boot = false
    }
    "k3s-w2" = {
      vmid      = 303
      pool_id   = "k3s"
      cores     = 2
      memory_mb = 2048
      disk_gb   = 30
      networks = [
        { bridge = "k8s", ip = "10.10.40.22/24", gateway = "10.10.40.1" }
      ]
      tags    = ["k3s", "agent"]
      started = false
      on_boot = false
      # scratch-* (400+): add entries here or via tfvars, pool_id = "lab", bridge = "lab".
    }
  }
}
