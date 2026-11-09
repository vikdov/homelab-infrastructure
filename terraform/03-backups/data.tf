# Stage 02 must be applied first (guests exist). The PBS datastore must also be
# configured (Ansible) before this stage is applied.
# Future HCP Terraform / remote backend: replace with backend = "remote" or
# the tfe_outputs data source.
data "terraform_remote_state" "workloads" {
  backend = "local"

  config = {
    path = "../02-workloads/terraform.tfstate"
  }
}
