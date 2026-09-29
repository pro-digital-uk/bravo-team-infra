# Separate state from the main stack, so CI never manages its own permissions.
# Apply this folder from your own machine, not from GitHub Actions.
terraform {
  backend "s3" {
    bucket  = "terraform-state-493245399435"
    key     = "iam/github-oidc.tfstate"
    region  = "eu-west-2"
    encrypt = true
  }
}
