# ---------------------------------------------------------------------------
# Proxmox connection
# ---------------------------------------------------------------------------

variable "proxmox_endpoint" {
  description = "Proxmox API URL, e.g. https://pve.lan:8006/"
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (self-signed certificate)"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Resource pools
# ---------------------------------------------------------------------------
#
# Map of pool ID => pool description.
#
# Pools provide a logical grouping for VMs and containers and can also be
# used as an ACL boundary.
#
variable "pools" {
  description = "Resource pools; ACLs can later be scoped per pool"
  type        = map(string) # pool_id => comment

  default = {
    core = "Always-on infrastructure (LXC 100/101/110/111, VM 120)"
    apps = "User applications (VM 200)"
    k3s  = "Kubernetes cluster (VMs 301-303)"
    lab  = "Scratch / testing (400+)"
  }
}

# ---------------------------------------------------------------------------
# Additional service accounts
# ---------------------------------------------------------------------------
#
# Additional accounts can be added without modifying the resource definitions.
# Each account receives the role specified here.
#
variable "extra_service_accounts" {
  description = "Additional Proxmox service accounts to create"
  type = map(object({
    comment = string
    role_id = string
    path    = optional(string, "/")
  }))

  default = {
    ansible    = { comment = "Ansible dynamic inventory", role_id = "PVEAuditor" }
    monitoring = { comment = "Prometheus exporter", role_id = "PVEAuditor" }
  }
}
