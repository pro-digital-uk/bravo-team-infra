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

variable "alpha_team_name" {
  description = "Name of the alpha team, used in tags"
  type        = string
  default     = "team-alpha"
}

variable "bravo_team_name" {
  description = "Name of the bravo team, used in tags"
  type        = string
  default     = "team-bravo"
}

variable "alpha_vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "bravo_vpc_cidr_block" {
  description = "CIDR block for the bravo VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "security_group_outbound_cidr_blocks" {
  description = "List of CIDR blocks for outbound traffic from security groups"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "project_name" {
  description = "Name of the project, used in tags"
  type        = string
  default     = "static-website"
}

