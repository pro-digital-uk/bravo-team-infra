# Same state as the stack CI already applied (27 resources), so this folder
# takes it over instead of creating a second copy.
terraform {
  backend "s3" {
    bucket  = "terraform-state-493245399435"
    key     = "dev/alpha/terraform.tfstate"
    region  = "eu-west-2"
    encrypt = true
  }
}
