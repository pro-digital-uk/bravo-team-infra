# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------
locals {
  project_name = "mupando"
  team_name    = "alpha"
  name_prefix  = "team-${local.team_name}-${local.project_name}"
  bucket_name  = "${local.name_prefix}-${var.environment}-bucket" # team-alpha-mupando-dev

  common_tags = {
    Project     = local.project_name
    Team        = local.team_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
