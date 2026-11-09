variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS certificate verification for the Proxmox API"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# PBS target (created by Ansible)
# ---------------------------------------------------------------------------
variable "pbs_guest" {
  description = "Guest name of the PBS LXC in stage 02; its first static IP is used as the server address."
  type        = string
  default     = "pbs"
}

variable "pbs_server" {
  description = "Override the PBS address (IP or hostname). Null = first static IP of pbs_guest."
  type        = string
  default     = null
}

variable "pbs_datastore" {
  description = "PBS datastore name created by Ansible."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9._-]{2,}$", var.pbs_datastore))
    error_message = "pbs_datastore must be a valid PBS datastore name (3+ characters: letters, digits, _ . -)."
  }
}

variable "pbs_fingerprint" {
  description = "SHA-256 fingerprint of the PBS certificate (proxmox-backup-manager cert info)."
  type        = string

  validation {
    condition     = can(regex("^([0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}$", var.pbs_fingerprint))
    error_message = "pbs_fingerprint must be a SHA-256 fingerprint (32 colon-separated hex bytes)."
  }
}

variable "pbs_username" {
  description = "PBS API token ID used by PVE, e.g. pve-backup@pbs!pve. Needs DatastoreBackup only (see notes)."
  type        = string
  default     = "pve-backup@pbs!pve"

  validation {
    condition     = can(regex("^[^@!]+@[^@!]+![^@!]+$", var.pbs_username))
    error_message = "pbs_username must be a token ID in the form user@realm!tokenname."
  }
}

variable "pbs_token_secret" {
  description = "Secret of the PBS API token. Supply via TF_VAR_pbs_token_secret, never tfvars."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.pbs_token_secret) > 0 && var.pbs_token_secret == trimspace(var.pbs_token_secret)
    error_message = "pbs_token_secret is empty or has leading/trailing whitespace (check how it was copied)."
  }
}

variable "pbs_namespace" {
  description = "Optional PBS namespace inside the datastore."
  type        = string
  default     = null
}

variable "pbs_encryption_key" {
  description = <<-EOT
    Optional client-side encryption key (JSON, from proxmox-backup-client key create).
    Supply via TF_VAR_pbs_encryption_key. Store a copy OFFLINE: without it,
    encrypted backups are unrecoverable. Null disables encryption.
  EOT
  type        = string
  default     = null
  sensitive   = true
}

variable "storage_id" {
  description = "Storage ID of the PBS entry inside Proxmox."
  type        = string
  default     = "pbs"
}

# ---------------------------------------------------------------------------
# Backup job
# ---------------------------------------------------------------------------
variable "backup_pools" {
  description = "Guests whose pool_id is listed here are backed up."
  type        = list(string)
  default     = ["core", "apps"]
}

variable "backup_exclude_guests" {
  description = "Guest names never backed up (PBS must not back up itself)."
  type        = list(string)
  default     = ["pbs"]
}

variable "backup_schedule" {
  description = "Proxmox calendar event, e.g. \"02:30\" or \"sun 03:00\"."
  type        = string
  default     = "02:30"

  validation {
    condition     = length(trimspace(var.backup_schedule)) > 0
    error_message = "backup_schedule must not be empty."
  }
}

variable "backup_mode" {
  description = "vzdump mode."
  type        = string
  default     = "snapshot"

  validation {
    condition     = contains(["snapshot", "suspend", "stop"], var.backup_mode)
    error_message = "backup_mode must be snapshot, suspend or stop."
  }
}

variable "backup_notification_mode" {
  description = "How the job reports results: notification-system (PVE notification targets) or legacy-sendmail."
  type        = string
  default     = "notification-system"

  validation {
    condition     = contains(["auto", "notification-system", "legacy-sendmail"], var.backup_notification_mode)
    error_message = "backup_notification_mode must be auto, notification-system or legacy-sendmail."
  }
}

variable "backup_enabled" {
  description = "Set false to keep the storage and job defined but paused."
  type        = bool
  default     = true
}
