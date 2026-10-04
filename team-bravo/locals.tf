# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------
locals {
  # AZ suffix => CIDR block
  bravo_public_subnets = {
    "2a" = "10.1.0.0/20"
    "2b" = "10.1.16.0/20"
  }

  bravo_private_subnets = {
    "2a" = "10.1.32.0/20"
    "2b" = "10.1.48.0/20"
  }

  bravo_instance_type = "t2.micro"
  bravo_bucket_name   = "supando"
}
