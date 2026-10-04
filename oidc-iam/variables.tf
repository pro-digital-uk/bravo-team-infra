variable "aws_region" {
  description = "Region the main stack deploys into (applies are restricted to it)"
  type        = string
  default     = "eu-west-2"
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the roles, as owner/name"
  type        = string
  default     = "pro-digital-uk/bravo-team-infra"
}

variable "github_sub_prefix" {
  description = <<-EOT
    Prefix of the OIDC token's "sub" claim for the repo. This repo uses GitHub's
    immutable subject format (owner@owner_id/repo@repo_id). Check it with:
    gh api repos/<owner>/<repo>/actions/oidc/customization/sub --jq .sub_claim_prefix
  EOT
  type        = string
  default     = "repo:pro-digital-uk@328376077/bravo-team-infra@1368417950"
}

variable "github_environment" {
  description = "GitHub environment the apply job runs in"
  type        = string
  default     = "dev"
}

variable "state_bucket" {
  description = "S3 bucket holding the main stack's Terraform state"
  type        = string
  default     = "terraform-state-493245399435"
}

variable "state_key_prefix" {
  description = "Prefix of the main stack's state objects in the bucket"
  type        = string
  default     = "dev/"
}

variable "managed_name_prefixes" {
  description = "Name prefixes of IAM roles, instance profiles and S3 buckets the team stacks create"
  type        = list(string)
  default     = ["alpha-", "bravo-"]
}
