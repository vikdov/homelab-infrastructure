# ---------------------------------------------------------------------------
# Ansible inventory
# ---------------------------------------------------------------------------
#
# Expose the guest inventory in a simple structure that can be consumed by
# Ansible. The output can later be used to generate a static inventory or
# replaced by a dynamic inventory without changing the guest definitions.
#
# Both LXC and VM guests are merged into one map keyed by guest name.
# DHCP addresses are excluded because they are not known from Terraform's
# static configuration.
#
# IP addresses are returned without CIDR prefixes because Ansible inventory
# typically needs the host address rather than the network notation.
# ---------------------------------------------------------------------------

output "inventory" {
  description = "Guests with vmid, type, pool and IPs (no CIDR)"

  value = merge(
    {
      for k, v in coalesce(var.lxc_guests, {}) : k => {
        type = "lxc"
        vmid = v.vmid
        pool = v.pool_id
        tags = v.tags

        ips = [
          for n in try(v.networks, []) :
          split("/", n.ip)[0]
          if n.ip != null && n.ip != "dhcp" && strcontains(n.ip, "/")
        ]
      }
    },
    {
      for k, v in coalesce(var.vm_guests, {}) : k => {
        type = "vm"
        vmid = v.vmid
        pool = v.pool_id
        tags = v.tags

        ips = [
          for n in try(v.networks, []) :
          split("/", n.ip)[0]
          if n.ip != null && n.ip != "dhcp" && strcontains(n.ip, "/")
        ]
      }
    }
  )
}

output "public_ssh_keys" {
  description = "Map of resolved SSH public keys injected into each guest"
  value = {
    vms  = local.resolved_vm_guest_ssh_keys
    lxcs = local.resolved_lxc_guest_ssh_keys
  }
  sensitive = true

}

output "global_ssh_keys" {
  description = "List of global SSH public keys injected into all guests"
  value       = var.global_ssh_keys
  sensitive   = true
}
