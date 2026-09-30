# -----------------------------------------------------------------------------
# Terraform & required providers
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Provider
# -----------------------------------------------------------------------------
provider "aws" {
  region = "eu-west-2"

  default_tags {
    tags = {
      Project     = "mupando"
      Team        = "alpha"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}
