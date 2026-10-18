# ---------------------------------------------------------------------------
# Proxmox firewall variables
# ---------------------------------------------------------------------------
#
# Model: every guest gets default-deny INPUT / allow OUTPUT at the Proxmox
# firewall. A baseline (ssh from mgmt, node_exporter from the monitoring
# guest, icmp from internal networks) is added to every guest automatically;
# anything service-specific goes in var.guest_firewall_rules.
#
# Because inter-vnet traffic is routed by the PVE host and filtered at the
# destination guest's NIC, "who may reach me" rules on the destination guest
# are what enforce isolation between vnets.
#
# Tokens usable in a rule's `from` list:
#   <guest name>   all IPs of that guest            (e.g. "edge", "mon")
#   vnet:<key>     CIDR of a vnet in var.vnets      (e.g. "vnet:k8s")
#   lan            var.lan_cidr
#   mgmt           vnet gateways (the PVE host, i.e. ProxyJump) + var.mgmt_cidrs
#   internal       every vnet CIDR
#   all            every vnet CIDR + the LAN
#   anything else is treated literally and must be an IPv4 address or CIDR
# Reserved tokens (lan, mgmt, internal, all, vnet:*) win over guest names.
# ---------------------------------------------------------------------------

variable "lan_cidr" {
  description = "Physical LAN (vmbr0) network."
  type        = string
  default     = "192.168.1.0/24"

  validation {
    condition     = can(cidrnetmask(var.lan_cidr))
    error_message = "lan_cidr must be a valid IPv4 CIDR."
  }
}

variable "mgmt_cidrs" {
  description = <<-EOT
    Addresses allowed to SSH to every guest, AS THE GUEST SEES THEM. The vnet
    gateways (PVE host, used by ProxyJump) are added automatically; list your
    controller/workstation LAN address here for guests reached directly via
    the LAN (net, edge). Keep identical to bootstrap_mgmt_cidrs in Ansible
    (see output.ansible_site_vars).
  EOT
  type        = list(string)
  default     = ["192.168.1.0/24"]

  validation {
    condition = length(var.mgmt_cidrs) > 0 && alltrue([
      for c in var.mgmt_cidrs :
      can(cidrnetmask(c)) || can(regex("^[0-9]{1,3}(\\.[0-9]{1,3}){3}$", c))
    ])
    error_message = "Set mgmt_cidrs to at least one IPv4 address or CIDR (see terraform.tfvars.example)."
  }
}

variable "monitoring_guest" {
  description = "Guest name (key in lxc_guests/vm_guests) that scrapes node_exporter and the PVE API."
  type        = string
  default     = "mon"
}

variable "firewall_activate" {
  description = <<-EOT
    Datacenter-level firewall switch. Rules and per-guest options are always
    created; nothing is enforced until this is true. Stage a rollout by
    applying with false, reviewing in the PVE UI, then applying with true.
  EOT
  type        = bool
  default     = false
}

variable "host_firewall_input_policy" {
  description = <<-EOT
    Datacenter/host INPUT policy. ACCEPT is the safe default (guests are
    still protected). Switch to DROP only after confirming mgmt_cidrs covers
    this machine: the datacenter rules allow tcp 22 and 8006 from mgmt, and
    8006 from the monitoring guest.
  EOT
  type        = string
  default     = "ACCEPT"

  validation {
    condition     = contains(["ACCEPT", "DROP"], var.host_firewall_input_policy)
    error_message = "host_firewall_input_policy must be ACCEPT or DROP."
  }
}

variable "ansible_vars_dir" {
  description = <<-EOT
    If set (e.g. "../ansible-bootstrap/inventory/host_vars"), Terraform writes
    <dir>/<vm name>/firewall.generated.yml containing bootstrap_firewall_extra_rules
    for every VM, derived from guest_firewall_rules. One source of truth for
    both firewall layers. Null disables generation.
  EOT
  type        = string
  default     = "../../ansible/inventory/host_vars"
}

variable "guest_firewall_rules" {
  description = "Extra inbound ACCEPT rules per guest, on top of the baseline. Keys are guest names."
  type = map(list(object({
    comment = string
    proto   = string               # tcp | udp | icmp
    dport   = optional(string, "") # "443", "80,443" or "30000:32767"
    from    = list(string)         # see tokens above
    iface   = optional(string, "") # e.g. "net0"; empty = any NIC
  })))

  validation {
    condition = alltrue([
      for rules in values(var.guest_firewall_rules) : alltrue([
        for r in rules : contains(["tcp", "udp", "icmp"], r.proto) && length(r.from) > 0
      ])
    ])
    error_message = "Every rule needs proto tcp|udp|icmp and a non-empty from list."
  }

  default = {
    net = [
      { comment = "dns udp", proto = "udp", dport = "53", from = ["all"] },
      { comment = "dns tcp", proto = "tcp", dport = "53", from = ["all"] },
      { comment = "pihole services (dns, web, dhcp)", proto = "tcp", dport = "53,80,443,67", from = ["mgmt"] },
    ]

    edge = [
      # Traefik. "net" = tailnet clients, who arrive SNATed by the subnet router.
      { comment = "traefik http/https", proto = "tcp", dport = "80,443", from = ["lan", "net"] },
      { comment = "traefik+cloudflared metrics", proto = "tcp", dport = "8082,20241", from = ["mon"] },
    ]

    mon = [
      { comment = "grafana + gatus via edge", proto = "tcp", dport = "3000,8080", from = ["edge", "mgmt"] },
      { comment = "prometheus + alertmanager ui", proto = "tcp", dport = "9090,9093", from = ["mgmt"] },
      { comment = "loki push (alloy)", proto = "tcp", dport = "3100", from = ["internal"] },
    ]

    pbs = [
      # The PVE host connects as the infra gateway, which is part of "mgmt".
      { comment = "pbs api/ui + pve backups", proto = "tcp", dport = "8007", from = ["mgmt"] },
    ]

    identity = [
      # Adjust to your compose port mappings (vaultwarden, authelia).
      { comment = "vaultwarden + authelia via edge", proto = "tcp", dport = "8080,9091", from = ["edge"] },
    ]

    apps = [
      # Adjust to your compose port mappings (nextcloud, immich).
      { comment = "nextcloud + immich via edge", proto = "tcp", dport = "2283,8080", from = ["edge"] },
    ]

    "k3s-cp1" = [
      { comment = "k8s api", proto = "tcp", dport = "6443", from = ["vnet:k8s", "mgmt"] },
      { comment = "kubelet", proto = "tcp", dport = "10250", from = ["vnet:k8s"] },
      { comment = "flannel vxlan", proto = "udp", dport = "8472", from = ["vnet:k8s"] },
    ]

    "k3s-w1" = [
      { comment = "kubelet", proto = "tcp", dport = "10250", from = ["vnet:k8s"] },
      { comment = "flannel vxlan", proto = "udp", dport = "8472", from = ["vnet:k8s"] },
      { comment = "nodeports via edge", proto = "tcp", dport = "30000:32767", from = ["edge"] },
    ]

    "k3s-w2" = [
      { comment = "kubelet", proto = "tcp", dport = "10250", from = ["vnet:k8s"] },
      { comment = "flannel vxlan", proto = "udp", dport = "8472", from = ["vnet:k8s"] },
      { comment = "nodeports via edge", proto = "tcp", dport = "30000:32767", from = ["edge"] },
    ]
  }
}
