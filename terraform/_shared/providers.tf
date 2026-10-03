# ---------------------------------------------------------------------------
# Proxmox provider
# ---------------------------------------------------------------------------
#
# Authenticate with the Terraform service account created by 00-bootstrap.
#
# The API token is supplied through the environment and must not be committed
# to the repository:
#
#   export PROXMOX_VE_API_TOKEN='terraform@pve!api=<secret>' #   export PROXMOX_VE_API_TOKEN='terraform@pve!api=<secret>' # gitleaks:allow
#
provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = var.proxmox_insecure
}
