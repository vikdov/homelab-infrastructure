# Identity & Location
variable "name" {
  description = "VM name and hostname"
  type        = string
}

variable "vm_id" {
  description = "Proxmox VM ID"
  type        = number
}

variable "node_name" {
  description = "Proxmox node on which the VM is created"
  type        = string
}

variable "pool_id" {
  description = "Proxmox resource pool for the VM"
  type        = string
}

variable "template_vm_id" {
  description = "VM ID of the template used to clone this guest"
  type        = number
}

variable "image_file_id" {
  description = "File ID of the downloaded image (e.g. local:iso/debian13.qcow2) used if template_vm_id is null."
  type        = string
  default     = null
}

# Compute & Storage
variable "cores" {
  description = "Virtual CPU cores"
  type        = number
}

variable "memory_mb" {
  description = "VM memory in MB"
  type        = number
}

variable "disk_gb" {
  description = "Boot disk size in GB"
  type        = number
}

variable "datastore_id" {
  description = "Datastore used for the VM boot disk and cloud-init data"
  type        = string
}

variable "extra_disks" {
  description = "Additional VM disks, attached as scsi1, scsi2, etc."
  type = list(object({
    size_gb      = number
    datastore_id = string
  }))
  default = []
}

# Networking
variable "networks" {
  description = "One entry per NIC, in order. ip is CIDR or \"dhcp\"."
  type = list(object({
    bridge  = string
    ip      = string
    gateway = optional(string)
  }))
}

variable "dns_servers" {
  description = "DNS servers configured through cloud-init"
  type        = list(string)
  default     = []
}

# Cloud-Init & Credentials
variable "ssh_public_keys" {
  description = "SSH public keys injected into the VM through cloud-init"
  type        = list(string)
}

variable "username" {
  description = "Initial cloud-init user"
  type        = string
  default     = "debian"
}

variable "vendor_data_file_id" {
  description = "Optional Proxmox snippet containing cloud-init vendor data"
  type        = string
  default     = null
}

# Runtime & Flags
variable "tags" {
  description = "Proxmox tags assigned to the VM"
  type        = list(string)
  default     = []
}

variable "started" {
  description = "Whether the VM should be running after creation"
  type        = bool
  default     = true
}

variable "on_boot" {
  description = "Start the VM automatically when the Proxmox node boots"
  type        = bool
  default     = false
}
