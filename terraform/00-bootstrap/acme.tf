# ---------------------------------------------------------------------------
# Trusted certificate for the PVE web UI / API (Let's Encrypt, DNS-01)
# ---------------------------------------------------------------------------
#
# Flow:
#   ACME account  ->  DNS plugin (API credentials)  ->  certificate order
#
# DNS-01 proves domain control by writing a TXT record through the DNS
# provider's API, so the PVE host does not need to be reachable from the
# internet and no port is forwarded.
#
# Renewal is handled by PVE itself, not Terraform: once the node's ACME
# domain is configured, pve-daily-update renews the certificate when it is
# close to expiry. `force = false` keeps Terraform from re-ordering on every
# apply.
#
# Everything is gated by var.acme_enabled so bootstrap works on a fresh host
# before DNS and credentials exist.
#
# Rollout (do it in this order):
#   1. Register the subdomain, point its A record at the PVE LAN IP.
#   2. Apply with the STAGING acme_directory to prove the plumbing.
#   3. Switch to the production directory (re-registers the account) and apply.
#   4. Set proxmox_endpoint to https://<acme_domain>:8006/ and
#      proxmox_insecure = false in every stage.
#
# Docs:
#
#
# ---------------------------------------------------------------------------

# Fail at plan time with a clear message instead of a half-created account.
resource "terraform_data" "acme_checks" {
  count = var.acme_enabled ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.acme_domain != null && can(regex("^([a-z0-9-]+\\.)+[a-z]{2,}$", var.acme_domain))
      error_message = "acme_enabled requires acme_domain to be a valid lowercase FQDN."
    }

    precondition {
      condition     = var.acme_contact != null && can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.acme_contact))
      error_message = "acme_enabled requires acme_contact to be a valid e-mail address."
    }

    precondition {
      condition     = var.acme_tos_url != null
      error_message = "acme_enabled requires acme_tos_url (see the directory's meta.termsOfService)."
    }

    precondition {
      condition     = length(var.acme_dns_data) > 0
      error_message = "acme_enabled requires acme_dns_data (DNS API credentials). Use TF_VAR_acme_dns_data."
    }
  }
}

# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/acme_account
resource "proxmox_acme_account" "this" {
  count = var.acme_enabled ? 1 : 0

  name      = var.acme_account_name
  contact   = var.acme_contact
  directory = var.acme_directory
  tos       = var.acme_tos_url

  depends_on = [terraform_data.acme_checks]
}

# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/acme_dns_plugin
resource "proxmox_acme_dns_plugin" "this" {
  count = var.acme_enabled ? 1 : 0

  plugin = var.acme_dns_plugin_id
  api    = var.acme_dns_api
  data   = var.acme_dns_data

  # Seconds to wait after writing the TXT record before validation starts.
  validation_delay = 30

  depends_on = [terraform_data.acme_checks]
}

# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/acme_certificate
resource "proxmox_acme_certificate" "this" {
  count = var.acme_enabled ? 1 : 0

  node_name = var.node_name
  account   = proxmox_acme_account.this[0].name
  force     = false

  domains = [{
    domain = var.acme_domain
    plugin = proxmox_acme_dns_plugin.this[0].plugin
  }]

  # Installing the certificate restarts pveproxy, which briefly drops API
  # connections. Order it after everything else in this stage so a transient
  # failure here never interrupts the other resources; a re-apply is safe.
  depends_on = [
    proxmox_virtual_environment_dns.this,
    proxmox_virtual_environment_time.this,
    proxmox_apt_standard_repository.no_subscription,
    proxmox_virtual_environment_file.template_user_data,
  ]
}
