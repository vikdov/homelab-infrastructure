# ---------------------------------------------------------------------------
# PVE host configuration
# ---------------------------------------------------------------------------
#
# Host-level settings that are not guests: package sources, resolvers, and
# time zone. They live in bootstrap because they are root-only API endpoints
# and every later stage (and Ansible) assumes they are already correct.
#
# Out of scope here, intentionally:
# - NTP daemon config (chrony): not exposed by the PVE API; handle in Ansible.
# - Package upgrades and reboots: Ansible.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Apt repositories
# ---------------------------------------------------------------------------
#
# 1. Disable the subscription-only enterprise repositories (these entries
#    already exist on a stock install; this only toggles them off).
# 2. Enable the pve-no-subscription repository.
#
# The no-subscription repository gets updates slightly earlier and with less
# testing than enterprise. That is acceptable for a homelab; the PBS
# snapshot/backup stage is the safety net for a bad update.
#
# Docs:
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/apt_repository
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/apt_standard_repository

resource "proxmox_apt_repository" "disabled" {
  for_each = { for r in var.apt_disabled_repositories : "${r.file_path}#${r.index}" => r }

  node      = var.node_name
  file_path = each.value.file_path
  index     = each.value.index
  enabled   = false
}

resource "proxmox_apt_standard_repository" "no_subscription" {
  node   = var.node_name
  handle = "no-subscription"
}

# ---------------------------------------------------------------------------
# DNS and time
# ---------------------------------------------------------------------------
#
# The DNS resource rewrites the host's /etc/resolv.conf. Note that PVE uses it
# for apt, ACME and PBS lookups, so a wrong value here breaks all three.
#
# Docs:
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_dns
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_time
#
resource "proxmox_virtual_environment_dns" "this" {
  node_name = var.node_name
  domain    = var.host_dns_domain
  servers   = var.host_dns_servers
}

resource "proxmox_virtual_environment_time" "this" {
  node_name = var.node_name
  time_zone = var.host_time_zone
}
