# ---------------------------------------------------------------------------
# Remote State from 01-platform
# ---------------------------------------------------------------------------
# Stage 01 must be applied before this stage.
# This stage consumes its Terraform state outputs.
data "terraform_remote_state" "platform" {
  backend = "local" # Adjust backend (s3, pg, etc.) if applicable

  config = {
    path = "../01-platform/terraform.tfstate"
  }
}
