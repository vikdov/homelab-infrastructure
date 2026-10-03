# ---------------------------------------------------------------------------
# Cloud-init user data
# ---------------------------------------------------------------------------
#
# The generic cloud images do not include qemu-guest-agent.
#
# This cloud-init configuration is attached to every template so that every
# VM cloned from the template installs and starts the QEMU guest agent during
# its first boot.
#
# The Proxmox VM resource in 01-platform/templates.tf also has
# agent.enabled = true. This controls the Proxmox-side expectation that the
# guest agent is available.
#
# ---------------------------------------------------------------------------
# Bootstrap-only SSH operation
# ---------------------------------------------------------------------------
#
# The bpg/proxmox provider does not perform this datastore configuration
# through the API in this workflow, so bootstrap uses SSH to the Proxmox host
# to enable the "snippets" content type.
#
# SSH credentials intentionally come from the bootstrap root credentials.
#
# The operation is idempotent: if snippets are already enabled, no change is
# made.
#
resource "terraform_data" "enable_snippets" {
  triggers_replace = [var.file_datastore, "v1"]

  connection {
    type     = "ssh"
    host     = regex("^https?://([^:/]+)", var.proxmox_endpoint)[0]
    user     = split("@", var.proxmox_username)[0] # "root@pam" -> "root"
    password = var.proxmox_password
    timeout  = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      # Check if snippets are already enabled for this datastore; exit early if true
      "pvesm status --content snippets | grep -q '^${var.file_datastore} ' && exit 0",
      # Fetch existing content types and append 'snippets' to them
      "cur=$(pvesm config ${var.file_datastore} | awk '/^content/{print $NF}')",
      "pvesm set ${var.file_datastore} --content \"$cur,snippets\"",
    ]
  }
}

# Uploads the cloud-init YAML configuration file to the Proxmox datastore snippet storage.
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_file
resource "proxmox_virtual_environment_file" "template_user_data" {
  node_name    = var.node_name
  datastore_id = var.file_datastore
  content_type = "snippets"

  source_raw {
    file_name = "template-qemu-guest-agent.yaml"
    data      = <<-YAML
      #cloud-config

      package_update: true

      packages:
        - qemu-guest-agent

      runcmd:
        - systemctl enable --now qemu-guest-agent
    YAML
  }

  # Guarantees snippets are enabled on the datastore before attempting to upload the file
  depends_on = [terraform_data.enable_snippets]
}
