# ---------------------------------------------------------------------------
# Proxmox SDN
# ---------------------------------------------------------------------------
#
# This file defines the homelab's isolated virtual networks.
#
# The SDN hierarchy is:
#
#   zone
#     └── VNet
#           └── subnet
#
# The zone provides the SDN namespace containing the homelab VNets. A VNet represents
# the virtual Layer-2 network that guests attach to, while the subnet
# provides Layer-3 addressing, gateway and NAT configuration.
#
# vmbr0 is the physical LAN bridge and is intentionally outside this SDN.
# Some guests can have both vmbr0 and an SDN VNet attached when they need
# access to both the physical LAN and an isolated internal network.
# ---------------------------------------------------------------------------

# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/sdn_zone_simple
#
# The zone is the container for the homelab's SDN VNets.
#
# A simple zone creates isolated virtual networks on the Proxmox node;
# it does not connect them directly to the physical LAN.
resource "proxmox_sdn_zone_simple" "homelab" {
  id    = "homelab"
  nodes = [var.node_name]
}

# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/sdn_vnet
#
# Create one VNet for every entry in var.vnets.
#
# Each VNet acts as a separate virtual Layer-2 network. Guests can attach
# their network interfaces to a VNet by using its ID as the bridge name.
#
# Using for_each keeps the network topology in var.vnets rather than
# duplicating one resource block for every network.
resource "proxmox_sdn_vnet" "this" {
  for_each = var.vnets

  id    = each.key
  zone  = proxmox_sdn_zone_simple.homelab.id
  alias = each.value.alias
}

# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/sdn_subnet
#
# Assign an IP subnet and gateway to each VNet.
#
# For example:
#
#   VNet:   infra
#   Subnet: 10.10.10.0/24
#   Gateway: 10.10.10.1
#
# SNAT allows guests on these isolated networks to reach external networks
# through the Proxmox host without requiring a route for every internal
# subnet on the physical LAN.
resource "proxmox_sdn_subnet" "this" {
  for_each = var.vnets

  cidr    = each.value.cidr
  vnet    = proxmox_sdn_vnet.this[each.key].id
  gateway = each.value.gateway

  # SNAT provides outbound connectivity through the Proxmox SDN.
  # It does not, by itself, provide isolation/firewall policy between
  # the VNets. Inter-network access control should be handled separately.
  snat = true
}

# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/sdn_applier
#
# SDN resources describe the desired configuration, but Proxmox applies
# that configuration separately. This resource performs that apply step.
#
# Keep it dependent on the complete SDN configuration so guests are not
# created before the networks they depend on are active.
resource "proxmox_sdn_applier" "this" {
  depends_on = [
    proxmox_sdn_zone_simple.homelab,
    proxmox_sdn_vnet.this,
    proxmox_sdn_subnet.this,
  ]

  lifecycle {
    replace_triggered_by = [
      proxmox_sdn_zone_simple.homelab,
      proxmox_sdn_vnet.this,
      proxmox_sdn_subnet.this,
    ]
  }
}
