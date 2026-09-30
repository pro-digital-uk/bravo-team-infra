terraform {
  backend "s3" {
    bucket = "terraform-state-493245399435"
    key    = "dev/demo/terraform.tfstate"
    region = "eu-west-2"
  }
}