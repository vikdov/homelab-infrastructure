# ---------------------------------------------------------------------------
# API tokens
# ---------------------------------------------------------------------------
#
# Bootstrap creates the API credentials used by subsequent Terraform stages.
#
# Token values are sensitive and are stored in Terraform state. Protect the
# bootstrap state accordingly and never commit it to Git.
#
# After bootstrap, securely transfer the required token to the next stage
# (for example, using a password/secret manager or environment variable).
#
# Read with:
#   terraform output -json api_tokens
#
output "api_tokens" {
  description = "Full API token strings per service account (user@pve!api=secret)."
  sensitive   = true

  value = {
    for k, t in proxmox_user_token.this : k => t.value
  }
}
