# TFLint config, shared by every stack. Run from inside a stack folder:
#   tflint --init --config=../.tflint.hcl && tflint --config=../.tflint.hcl
# CI runs this for team-alpha, team-bravo and oidc-iam.

config {
  call_module_type = "local"
}

# Core Terraform rules (unused declarations, missing types, naming, etc.)
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# AWS rules: invalid instance types, AMI and region values, deprecated arguments
plugin "aws" {
  enabled = true
  version = "0.40.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
