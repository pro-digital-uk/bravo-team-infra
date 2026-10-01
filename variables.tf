# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Deployment environment, used in tags"
  type        = string
  default     = "dev"
}

variable "enable_nat_gateway" {
  description = <<-EOT
    Create the NAT gateway (and its Elastic IP and route) so private subnets
    can reach the internet. Costs about $32/month plus data while enabled.
    When false, the private instance has no internet access or SSM access.
  EOT
  type        = bool
  default     = false
}
