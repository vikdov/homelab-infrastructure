# ---------------------------------------------------------------------------
# Proxmox provider
# ---------------------------------------------------------------------------
#
# Bootstrap authenticates as root@pam because the Terraform service account
# does not exist yet. This stage creates that account and its permissions.
#
# Credentials are supplied through environment variables and must never be
# stored in Terraform configuration, *.tfvars files, or Git.
#
#   export PROXMOX_VE_USERNAME='root@pam'
#   export PROXMOX_VE_PASSWORD='...'
#
# After bootstrap, subsequent stages should authenticate using the dedicated
# Terraform service account instead of root@pam.
#
# Docs:
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs
#
provider "proxmox" {
  endpoint = var.proxmox_endpoint

  # Only enable for a trusted/self-signed certificate during bootstrap.
  # Prefer a properly trusted certificate in normal operation.
  insecure = var.proxmox_insecure
}


