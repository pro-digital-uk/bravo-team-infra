# -----------------------------------------------------------------------------
# VPC - network, NAT, default SG lockdown, flow logs
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.alpha_vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.alpha_team_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.alpha_team_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = var.security_group_outbound_cidr_blocks[0]
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.alpha_team_name}-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.alpha_team_name}-private-rt"
  }
}

resource "aws_subnet" "public" {
  for_each = local.alpha_public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.alpha_public_subnets[each.key]
  availability_zone       = "${var.aws_region}${substr(each.key, -1, 1)}"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.alpha_team_name}-public-subnet-${each.key}"
  }
}

resource "aws_subnet" "private" {
  for_each = local.alpha_private_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.alpha_private_subnets[each.key]
  availability_zone       = "${var.aws_region}${substr(each.key, -1, 1)}"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.alpha_team_name}-private-subnet-${each.key}"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
#Bravo team VPC - KA
resource "aws_vpc" "bravo" {
  cidr_block           = var.bravo_vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.bravo_team_name}-vpc"
  }
}

resource "aws_internet_gateway" "bravo" {
  vpc_id = aws_vpc.bravo.id

  tags = {
    Name = "${var.bravo_team_name}-igw"
  }
}

resource "aws_route_table" "bravo_public" {
  vpc_id = aws_vpc.bravo.id

  route {
    cidr_block = var.security_group_outbound_cidr_blocks[0]
    gateway_id = aws_internet_gateway.bravo.id
  }

  tags = {
    Name = "${var.bravo_team_name}-public-rt"
  }
}

resource "aws_route_table" "bravo_private" {
  vpc_id = aws_vpc.bravo.id

  tags = {
    Name = "${var.bravo_team_name}-private-rt"
  }
}

resource "aws_subnet" "bravo_public" {
  for_each = local.bravo_public_subnets

  vpc_id                  = aws_vpc.bravo.id
  cidr_block              = local.bravo_public_subnets[each.key]
  availability_zone       = "${var.aws_region}${substr(each.key, -1, 1)}"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.bravo_team_name}-public-subnet-${each.key}"
  }
}

resource "aws_subnet" "bravo_private" {
  for_each = local.bravo_private_subnets

  vpc_id                  = aws_vpc.bravo.id
  cidr_block              = local.bravo_private_subnets[each.key]
  availability_zone       = "${var.aws_region}${substr(each.key, -1, 1)}"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.bravo_team_name}-private-subnet-${each.key}"
  }
}

resource "aws_route_table_association" "bravo_public" {
  for_each = aws_subnet.bravo_public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.bravo_public.id
}

resource "aws_route_table_association" "bravo_private" {
  for_each = aws_subnet.bravo_private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.bravo_private.id
}

# NAT gateway, its Elastic IP and the private default route only exist when
# # var.enable_nat_gateway is true (about $32/month + data while it runs).
# resource "aws_route" "private_nat" {
#   count = var.enable_nat_gateway ? 1 : 0

#   route_table_id         = aws_route_table.private.id
#   destination_cidr_block = var.security_group_outbound_cidr_blocks[0]
#   nat_gateway_id         = aws_nat_gateway.main[0].id
# }

# resource "aws_nat_gateway" "main" {
#   count = var.enable_nat_gateway ? 1 : 0

#   allocation_id = aws_eip.nat[0].id
#   subnet_id     = aws_subnet.public["2a"].id

#   tags = {
#     Name = "${var.team_name}-nat-gateway"
#   }
# }

# resource "aws_eip" "nat" {
#   count = var.enable_nat_gateway ? 1 : 0

#   domain = "vpc"
#   tags = {
#     Name = "${var.team_name}-nat-eip"
#   }
#   depends_on = [aws_internet_gateway.main]
# }

# # Take over the VPC's default security group and strip all rules from it,
# # so nothing can accidentally rely on it.
# resource "aws_default_security_group" "default" {
#   vpc_id = aws_vpc.main.id

#   tags = {
#     Name = "${var.team_name}-default-sg-locked"
#   }
# }

# resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
#   name              = "/vpc/${var.team_name}-vpc/flow-logs"
#   retention_in_days = 30
# }

# data "aws_iam_policy_document" "vpc_flow_logs_assume" {
#   statement {
#     actions = ["sts:AssumeRole"]

#     principals {
#       type        = "Service"
#       identifiers = ["vpc-flow-logs.amazonaws.com"]
#     }
#   }
# }

# resource "aws_iam_role" "vpc_flow_logs" {
#   name               = "${var.team_name}-vpc-flow-logs"
#   assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume.json
# }

# data "aws_iam_policy_document" "vpc_flow_logs" {
#   statement {
#     actions = [
#       "logs:CreateLogStream",
#       "logs:PutLogEvents",
#       "logs:DescribeLogStreams",
#     ]
#     resources = ["${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"]
#   }
# }

# resource "aws_iam_role_policy" "vpc_flow_logs" {
#   name   = "vpc-flow-logs-to-cloudwatch"
#   role   = aws_iam_role.vpc_flow_logs.id
#   policy = data.aws_iam_policy_document.vpc_flow_logs.json
# }

# resource "aws_flow_log" "main" {
#   vpc_id               = aws_vpc.main.id
#   traffic_type         = "ALL"
#   log_destination_type = "cloud-watch-logs"
#   log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
#   iam_role_arn         = aws_iam_role.vpc_flow_logs.arn

#   tags = {
#     Name = "${var.team_name}-vpc-flow-log"
#   }
# }
