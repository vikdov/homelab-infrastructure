output "backup_storage_id" {
  description = "PVE storage ID of the PBS target."
  value       = proxmox_storage_pbs.this.id
}

output "backup_vmids" {
  description = "VM/CT IDs included in the backup job."
  value       = local.backup_vmids
}
