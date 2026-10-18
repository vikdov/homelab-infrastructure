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

variable "proxmox_username" {
  description = "Proxmox username"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
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
    comment    = string
    role_id    = string
    path       = optional(string, "/")
    token_name = optional(string, "api")
  }))

  default = {
    ansible    = { comment = "Ansible dynamic inventory", role_id = "PVEAuditor" }
    monitoring = { comment = "Prometheus exporter", role_id = "PVEAuditor" }
  }
}

# --------------------------------------------------------------------------
# Proxmox node and storage
# --------------------------------------------------------------------------
#
# For snippets.tf which are used by templates.tf
#
variable "node_name" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

variable "file_datastore" {
  description = "Proxmox storage ID for downloaded files (snippets, cloud-init, ISO, etc.)"
  type        = string
  default     = "local"
}

# ---------------------------------------------------------------------------
# Host: apt repositories
# ---------------------------------------------------------------------------
#
# A fresh PVE install enables the enterprise repositories, which return
# 401 without a subscription and break `apt update` (and Ansible upgrades).
#

variable "apt_disabled_repositories" {
  description = "Existing apt repository entries to disable (enterprise repos need a subscription)."
  type = list(object({
    file_path = string
    index     = optional(number, 0)
  }))

  default = [
    { file_path = "/etc/apt/sources.list.d/pve-enterprise.sources" },
    { file_path = "/etc/apt/sources.list.d/ceph.sources" },
  ]
}

# ---------------------------------------------------------------------------
# Host: DNS and time
# ---------------------------------------------------------------------------
variable "host_dns_domain" {
  description = "Search domain for the PVE host. home.arpa is reserved for home networks (RFC 8375)."
  type        = string
  default     = "home.arpa"
}

variable "host_dns_servers" {
  description = <<-EOT
    Resolvers for the PVE host (PVE accepts at most three), tried in order.
    Pi-hole (guest "net") comes first so the host resolves local names.
    While it is down (host boot, restore, maintenance), each lookup waits
    for the first server to time out before falling through to the public
    resolvers, so the host stays functional but slow.
    For a host that never depends on a guest, drop the first entry.
  EOT
  type        = list(string)
  default     = ["192.168.1.100", "1.1.1.1", "9.9.9.9"]

  validation {
    condition     = length(var.host_dns_servers) >= 1 && length(var.host_dns_servers) <= 3
    error_message = "host_dns_servers must contain between 1 and 3 addresses."
  }
}

variable "host_time_zone" {
  description = "Host time zone (tz database name). Backup schedules are evaluated in this zone."
  type        = string
  default     = "Europe/Warsaw"
}

# ---------------------------------------------------------------------------
# ACME / trusted certificate
# ---------------------------------------------------------------------------
variable "acme_enabled" {
  description = "Order and install a Let's Encrypt certificate for the PVE web/API endpoint."
  type        = bool
  default     = false
}

variable "acme_domain" {
  description = "FQDN of the free subdomain (e.g. myhomelab.duckdns.org). Its A record should resolve to the PVE host."
  type        = string
  default     = null
}

variable "acme_contact" {
  description = "Contact e-mail for Let's Encrypt expiry notices. Supply via TF_VAR_acme_contact; do not commit."
  type        = string
  default     = null
}

variable "acme_directory" {
  description = <<-EOT
    ACME directory URL. Use the staging directory first to avoid production
    rate limits while testing (staging certificates are NOT browser-trusted).
    Changing it re-registers the account.
      staging:    https://acme-staging-v02.api.letsencrypt.org/directory
      production: https://acme-v02.api.letsencrypt.org/directory
  EOT
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}

variable "acme_tos_url" {
  description = "Let's Encrypt terms-of-service URL accepted when registering the account. Get the current one from the directory URL's `meta.termsOfService`."
  type        = string
  default     = null
}

variable "acme_account_name" {
  description = "Name of the ACME account inside Proxmox."
  type        = string
  default     = "default"
}

variable "acme_dns_plugin_id" {
  description = "ID of the DNS plugin entry inside Proxmox."
  type        = string
  default     = "duckdns"
}

variable "acme_dns_api" {
  description = "acme.sh DNS API script name (duckdns, desec, cloudflare, ...)."
  type        = string
  default     = "duckdns"
}

variable "acme_dns_data" {
  description = <<-EOT
    Credentials for the DNS API, as the acme.sh variable names it expects,
    e.g. { DuckDNS_Token = "..." } (deSEC: { DEDYN_TOKEN = "..." }).
    Supply via TF_VAR_acme_dns_data='{"DuckDNS_Token":"..."}'. Stored in state.
  EOT
  type        = map(string)
  default     = {}
  sensitive   = true
}
