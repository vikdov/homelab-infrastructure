# Provider
variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS certificate verification for the Proxmox API"
  type        = bool
  default     = false
}

variable "node_name" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

# Storage & Infrastructure Defaults
variable "vm_datastore" {
  description = "Datastore for VM and LXC root disks"
  type        = string
  default     = "local-lvm"
}

variable "file_datastore" {
  description = "Proxmox datastore for imported images, LXC templates and cloud-init snippets"
  type        = string
  default     = "local"
}

variable "template_bridge" {
  description = "Bridge/VNet attached to platform VM templates."
  type        = string
  default     = "vmbr0"
}

variable "lxc_templates" {
  description = "LXC template archives available to platform containers."

  type = map(object({
    description        = optional(string)
    download_url       = string
    file_name          = optional(string)
    checksum           = optional(string)
    checksum_algorithm = optional(string, "sha256")
  }))

  default = {
    debian13 = {
      description  = "Debian 13 LXC template"
      download_url = "http://download.proxmox.com/images/system/debian-13-standard_13.6-1_amd64.tar.zst"
    }
  }
  validation {
    condition = alltrue([
      for k, v in var.lxc_templates : v != null && length(v.download_url) > 0 && can(regex("^https?://", v.download_url))
    ])
    error_message = "All lxc_templates entries must include a valid non-empty 'download_url' starting with http:// or https://."
  }
  validation {
    condition = alltrue([
      for v in var.lxc_templates :
      contains(
        ["md5", "sha1", "sha224", "sha256", "sha384", "sha512"],
        v.checksum_algorithm
      )
    ])

    error_message = "checksum_algorithm must be one of md5, sha1, sha224, sha256, sha384, or sha512."
  }
}

variable "vm_images" {
  description = "VM operating-system images used to build Proxmox VM templates."

  type = map(object({
    description        = optional(string)
    download_url       = string
    file_name          = optional(string)
    checksum           = optional(string)
    checksum_algorithm = optional(string, "sha256")
  }))

  default = {
    debian13 = {
      description  = "debian-13-genericcloud-amd64 generic cloud image"
      download_url = "https://cloud.debian.org/images/cloud/trixie/20260914-2601/debian-13-genericcloud-amd64-20260914-2601.qcow2"
    }
  }
  validation {
    condition = alltrue([
      for k, v in var.vm_images : v != null && length(v.download_url) > 0 && can(regex("^https?://", v.download_url))
    ])
    error_message = "All vm_images entries must include a valid non-empty 'download_url' starting with http:// or https://."
  }
  validation {
    condition = alltrue([
      for v in var.vm_images :
      contains(
        ["md5", "sha1", "sha224", "sha256", "sha384", "sha512"],
        v.checksum_algorithm
      )
    ])

    error_message = "checksum_algorithm must be one of md5, sha1, sha224, sha256, sha384, or sha512."
  }
}

variable "template_vm_id_map" {
  description = "Optional map of VM image keys to explicit VM IDs for templates. When empty, a template is created for every VM image."
  type        = map(number)
  default     = {}

  validation {
    condition = alltrue([
      for image_name in keys(var.template_vm_id_map) :
      contains(keys(var.vm_images), image_name)
    ])

    error_message = "Every template_vm_id_map key must reference an existing vm_images key."
  }

  validation {
    condition = alltrue([
      for vm_id in values(var.template_vm_id_map) :
      vm_id >= 100
    ])

    error_message = "Template VM IDs must be valid positive Proxmox VM IDs."
  }
}

variable "template_user_data_file_name" {
  description = "Cloud-init snippet created in 00-bootstrap"
  type        = string
  default     = "template-qemu-guest-agent.yaml"
}

# Network & SDN resource
variable "dns_servers" {
  description = "List of DNS servers for all created guests"
  type        = list(string)
  default     = ["1.1.1.1", "9.9.9.9"]
}
variable "vnets" {
  description = "Homelab SDN VNets and their IPv4 gateways"
  type = map(object({
    alias   = string
    cidr    = string
    gateway = string
  }))

  default = {
    infra = {
      alias   = "Infrastructure"
      cidr    = "10.10.10.0/24"
      gateway = "10.10.10.1"
    }

    dmz = {
      alias   = "DMZ - edge"
      cidr    = "10.10.20.0/24"
      gateway = "10.10.20.1"
    }

    apps = {
      alias   = "User apps"
      cidr    = "10.10.30.0/24"
      gateway = "10.10.30.1"
    }

    k8s = {
      alias   = "k3s cluster"
      cidr    = "10.10.40.0/24"
      gateway = "10.10.40.1"
    }

    lab = {
      alias   = "Lab"
      cidr    = "10.10.50.0/24"
      gateway = "10.10.50.1"
    }
  }
  validation {
    condition = alltrue([
      length(var.vnets) > 0,
      alltrue([
        for v in var.vnets :
        length(trimspace(v.alias)) > 0 &&
        can(cidrnetmask(v.cidr)) &&
        can(cidrhost(v.cidr, 1)) &&
        # Strip the mask first, then compare the first 3 octets safely
        join(".", slice(split(".", v.gateway), 0, 3)) == join(".", slice(split(".", split("/", v.cidr)[0]), 0, 3))
      ])
    ])

    error_message = "Each VNet must have a non-empty alias, a valid IPv4 CIDR, and a gateway address that belongs to that specific CIDR."
  }
}
