# ---------------------------------------------------------------------------
# Terraform and provider versions
# ---------------------------------------------------------------------------
#
# Single source of truth for Terraform and provider version constraints.
#
# This file is shared by all stages through a symlink:
#   ln -s ../_shared/versions.tf versions.tf
#
# Keeping the constraints here ensures every stage uses the same Terraform
# and Proxmox provider versions.
#
terraform {
  # Allow Terraform 1.16.x releases, but not 1.17 or newer.
  required_version = "~> 1.16.0"

  required_providers {
    proxmox = {
      source = "bpg/proxmox"

      # Allow 0.114.x releases, but not 0.115 or newer.
      version = "~> 0.114.0"
    }
  }
}
