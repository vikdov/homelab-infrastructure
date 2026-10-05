# Identity & Core
variable "name" {
  description = "Hostname and name for the container"
  type        = string
}

variable "vm_id" {
  description = "Proxmox container ID"
  type        = number
}

variable "node_name" {
  description = "Proxmox node on which the container is created"
  type        = string
}

variable "pool_id" {
  description = "Proxmox resource pool for the container"
  type        = string
  default     = null
}

# Hardware Resources
variable "cores" {
  description = "Allocated CPU cores"
  type        = number
}

variable "memory_mb" {
  description = "Dedicated RAM in MB"
  type        = number
}

variable "swap_mb" {
  description = "Swap size allocated to the container in MB"
  type        = number
  default     = 0
}

# Storage
variable "disk_gb" {
  description = "Root filesystem size in GB"
  type        = number
}

variable "datastore_id" {
  description = "Datastore used for the container root filesystem"
  type        = string
}

variable "mount_options" {
  description = "Additional mount options for the container root filesystem"
  type        = list(string)
  default     = []
}

variable "mount_points" {
  description = "Optional additional volumes mounted inside the container"
  type = list(object({
    path          = string
    volume        = string
    size          = optional(string)
    mount_options = optional(list(string), [])
  }))
  default = null
}

# Network & Access
variable "networks" {
  description = "One entry per NIC (eth0, eth1, ...). ip is CIDR or \"dhcp\"."
  type = list(object({
    bridge  = string
    ip      = string
    gateway = optional(string)
  }))
}

variable "dns_servers" {
  description = "DNS servers configured inside the container"
  type        = list(string)
  default     = []
}

variable "ssh_public_keys" {
  description = "SSH public keys injected into the container"
  type        = list(string)
}

# Flags & Runtime Parameters
variable "template_file_id" {
  description = "Proxmox LXC template file ID"
  type        = string
}

variable "nesting" {
  description = "Enable LXC nesting for workloads that require nested containers"
  type        = bool
  default     = false
}

variable "protection" {
  description = "Prevent accidental deletion or destructive changes to the container"
  type        = bool
}

variable "tags" {
  description = "Proxmox tags assigned to the container"
  type        = list(string)
  default     = []
}

variable "started" {
  description = "Whether the container should be running after creation"
  type        = bool
  default     = true
}

variable "on_boot" {
  description = "Start the container automatically when the Proxmox node boots"
  type        = bool
  default     = true
}
