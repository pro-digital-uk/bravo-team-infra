# # -----------------------------------------------------------------------------
# # Outputs
# # -----------------------------------------------------------------------------
# output "vpc_id" {
#   description = "ID of the VPC"
#   value       = aws_vpc.main.id
# }

# output "public_subnet_ids" {
#   description = "Public subnet IDs by AZ suffix"
#   value       = { for k, s in aws_subnet.public : k => s.id }
# }

# output "private_subnet_ids" {
#   description = "Private subnet IDs by AZ suffix"
#   value       = { for k, s in aws_subnet.private : k => s.id }
# }

# output "nat_gateway_id" {
#   description = "ID of the NAT gateway (null when enable_nat_gateway is false)"
#   value       = one(aws_nat_gateway.main[*].id)
# }


# output "flow_log_group" {
#   description = "CloudWatch log group receiving VPC flow logs"
#   value       = aws_cloudwatch_log_group.vpc_flow_logs.name
# }



# output "web_public_instance_id" {
#   description = "ID of the public web instance"
#   value       = aws_instance.web_2a_public.id
# }

# output "web_public_ip" {
#   description = "Public IP of the public web instance"
#   value       = aws_instance.web_2a_public.public_ip
# }

# output "web_private_instance_id" {
#   description = "ID of the private web instance"
#   value       = aws_instance.web_2a_private.id
# }


# output "web_private_ip" {
#   description = "Private IP of the private web instance"
#   value       = aws_instance.web_2a_private.private_ip
# }
