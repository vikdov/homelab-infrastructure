# ---------------------------------------------------------------------------
# Proxmox firewall
# ---------------------------------------------------------------------------
#
# Apply order (enforced with depends_on):
#
#   guests exist -> checks -> per-guest rules -> per-guest options (enabled)
#                                             -> datacenter rules
#                                             -> datacenter firewall ON
#
# Guest-level options are inert until the datacenter firewall is switched on,
# so turning it on is the single cut-over point (see var.firewall_activate).
#
# PREREQUISITE (in the guest modules): every NIC needs the firewall flag,
# otherwise the guest's rules are never evaluated:
#   VM:  network_device    { firewall = true }
#   LXC: network_interface { firewall = true }
#
# Resource names follow the bpg provider's firewall docs
# (proxmox_virtual_environment_firewall_*). If your provider version renamed
# them like the proxmox_sdn_* resources, `terraform validate` will say so.
# ---------------------------------------------------------------------------

locals {
  vnets       = local.platform.vnets
  guest_names = concat(keys(var.lxc_guests), keys(var.vm_guests))

  # Guest -> its static IPv4 addresses (all NICs). DHCP NICs are skipped.
  guest_ips = merge(
    { for n, g in var.lxc_guests : n => [for nic in g.networks : split("/", nic.ip)[0] if can(cidrhost(nic.ip, 0))] },
    { for n, g in var.vm_guests : n => [for nic in g.networks : split("/", nic.ip)[0] if can(cidrhost(nic.ip, 0))] },
  )

  # The PVE host appears on each vnet as its gateway address; this is the
  # source address guests see for ProxyJump SSH and for PVE -> PBS backups.
  mgmt_sources = distinct(concat([for v in local.vnets : v.gateway], var.mgmt_cidrs))

  # Map abstract source tokens (guest names, vnet:<key>, lan, mgmt, internal, all)
  # to their concrete IPv4 addresses or CIDR blocks used in firewall rules.
  sources = tomap(merge(
    local.guest_ips,
    { for k, v in local.vnets : "vnet:${k}" => [v.cidr] },
    {
      lan      = [var.lan_cidr]
      mgmt     = local.mgmt_sources
      internal = [for v in local.vnets : v.cidr]
      all      = concat([for v in local.vnets : v.cidr], [var.lan_cidr])
    },
  ))

  # Applied to every guest.
  baseline_rules = [
    { comment = "ssh from mgmt", proto = "tcp", dport = "22", from = ["mgmt"], iface = "" },
    { comment = "node_exporter from monitoring", proto = "tcp", dport = "9100", from = [var.monitoring_guest], iface = "" },
    { comment = "icmp from internal", proto = "icmp", dport = "", from = ["internal"], iface = "" },
  ]

  # Resolve `from` tokens into the comma-separated source string PVE expects.
  lxc_rules = {
    for n, g in var.lxc_guests : n => [
      for r in concat(local.baseline_rules, lookup(var.guest_firewall_rules, n, [])) : {
        comment = r.comment
        proto   = r.proto
        dport   = r.dport
        iface   = r.iface
        source  = join(",", distinct(flatten([for s in r.from : lookup(local.sources, s, [s])])))
      }
    ]
  }

  vm_rules = {
    for n, g in var.vm_guests : n => [
      for r in concat(local.baseline_rules, lookup(var.guest_firewall_rules, n, [])) : {
        comment = r.comment
        proto   = r.proto
        dport   = r.dport
        iface   = r.iface
        source  = join(",", distinct(flatten([for s in r.from : lookup(local.sources, s, [s])])))
      }
    ]
  }

  # bootstrap_firewall_extra_rules for the in-guest nftables layer (VMs only,
  # service rules only: ssh/node_exporter are already in the bootstrap role).
  # One entry per port because nft needs `dport 80` / `dport 80-90`, not "80,443".
  ansible_firewall_vars = var.ansible_vars_dir == null ? {} : {
    for n, g in var.vm_guests : n => flatten([
      for r in lookup(var.guest_firewall_rules, n, []) : [
        for p in split(",", r.dport) : {
          proto   = r.proto
          port    = replace(trimspace(p), ":", "-")
          from    = distinct(flatten([for s in r.from : lookup(local.sources, s, [s])]))
          comment = r.comment
        }
      ] if contains(["tcp", "udp"], r.proto) && r.dport != ""
    ])
  }
}

# Fail early, at plan time, on typos that would otherwise silently open or
# close the wrong thing.
resource "terraform_data" "firewall_checks" {
  lifecycle {
    precondition {
      condition     = contains(local.guest_names, var.monitoring_guest)
      error_message = "monitoring_guest '${var.monitoring_guest}' is not a key in lxc_guests or vm_guests."
    }

    precondition {
      condition     = alltrue([for n in keys(var.guest_firewall_rules) : contains(local.guest_names, n)])
      error_message = "guest_firewall_rules has a key that is not a guest in lxc_guests or vm_guests."
    }

    precondition {
      condition = alltrue(flatten([
        for rules in values(var.guest_firewall_rules) : [
          for r in rules : [
            for s in r.from : contains(keys(local.sources), s) || can(regex("^[0-9.]+(/[0-9]+)?$", s))
          ]
        ]
      ]))
      error_message = "A rule's `from` contains a token that is not a guest, vnet:<key>, lan, mgmt, internal, all, or an IPv4 address/CIDR."
    }
  }
}

# ---------------------------------------------------------------------------
# Per-guest rules
# ---------------------------------------------------------------------------
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_firewall_rules

resource "proxmox_virtual_environment_firewall_rules" "lxc" {
  for_each = var.lxc_guests

  node_name    = local.node_name
  container_id = each.value.vmid

  dynamic "rule" {
    for_each = local.lxc_rules[each.key]
    content {
      type    = "in"
      action  = "ACCEPT"
      comment = rule.value.comment
      proto   = rule.value.proto
      dport   = rule.value.dport != "" ? rule.value.dport : null
      source  = rule.value.source
      iface   = rule.value.iface != "" ? rule.value.iface : null
    }
  }

  depends_on = [terraform_data.firewall_checks, module.lxc]
}

resource "proxmox_virtual_environment_firewall_rules" "vm" {
  for_each = var.vm_guests

  node_name = local.node_name
  vm_id     = each.value.vmid

  dynamic "rule" {
    for_each = local.vm_rules[each.key]
    content {
      type    = "in"
      action  = "ACCEPT"
      comment = rule.value.comment
      proto   = rule.value.proto
      dport   = rule.value.dport != "" ? rule.value.dport : null
      source  = rule.value.source
      iface   = rule.value.iface != "" ? rule.value.iface : null
    }
  }

  depends_on = [terraform_data.firewall_checks, module.vm]
}

# ---------------------------------------------------------------------------
# Per-guest options: enable + default deny inbound. Created after the rules so
# a guest is never enabled with an empty ruleset.
# ---------------------------------------------------------------------------
#
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_firewall_options
resource "proxmox_virtual_environment_firewall_options" "lxc" {
  for_each = var.lxc_guests

  node_name    = local.node_name
  container_id = each.value.vmid

  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
  log_level_in  = "nolog"
  log_level_out = "nolog"

  depends_on = [proxmox_virtual_environment_firewall_rules.lxc]
}

resource "proxmox_virtual_environment_firewall_options" "vm" {
  for_each = var.vm_guests

  node_name = local.node_name
  vm_id     = each.value.vmid

  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
  log_level_in  = "nolog"
  log_level_out = "nolog"

  depends_on = [proxmox_virtual_environment_firewall_rules.vm]
}

# ---------------------------------------------------------------------------
# Datacenter / Cluster wide
# ---------------------------------------------------------------------------

# Keeps SSH and the PVE API reachable if host_firewall_input_policy is DROP.
resource "proxmox_virtual_environment_firewall_rules" "host" {
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "ssh + pve ui/api from mgmt"
    proto   = "tcp"
    dport   = "22,8006"
    source  = join(",", local.mgmt_sources)
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "pve api from monitoring (pve-exporter)"
    proto   = "tcp"
    dport   = "8006"
    source  = join(",", local.sources[var.monitoring_guest])
  }

  depends_on = [terraform_data.firewall_checks]
}

# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_cluster_firewall
#
# The cut-over. Everything above is prepared but inert until this is enabled.
resource "proxmox_virtual_environment_cluster_firewall" "this" {
  enabled       = var.firewall_activate
  input_policy  = var.host_firewall_input_policy
  output_policy = "ACCEPT"
  ebtables      = true

  depends_on = [
    proxmox_virtual_environment_firewall_options.lxc,
    proxmox_virtual_environment_firewall_options.vm,
    proxmox_virtual_environment_firewall_rules.host,
  ]
}

# ---------------------------------------------------------------------------
# Generated Ansible vars (optional): keeps nftables on VMs in sync with the
# rules above. Requires the hashicorp/local provider.
# ---------------------------------------------------------------------------
# https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file

resource "local_file" "ansible_firewall" {
  for_each = local.ansible_firewall_vars

  filename        = "${var.ansible_vars_dir}/${each.key}/firewall.generated.yml"
  file_permission = "0644"
  content = join("\n", [
    "# Generated by Terraform (firewall.tf). Do not edit; change guest_firewall_rules instead.",
    yamlencode({ bootstrap_firewall_extra_rules = each.value }),
  ])
}
