# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
}

variable "environment" {
  description = "Deployment environment, used in tags"
  type        = string
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

variable "team_name" {
  description = "Name of the bravo team, used in tags"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "security_group_outbound_cidr_blocks" {
  description = "List of CIDR blocks for outbound traffic from security groups"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "project_name" {
  description = "Name of the project, used in tags"
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket to create"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the private instance"
  type        = string
}

