# -----------------------------------------------------------------------------
# VPC - network, NAT, default SG lockdown, flow logs
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.team_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.team_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = var.security_group_outbound_cidr_blocks[0]
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.team_name}-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.team_name}-private-rt"
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnets[each.key]
  availability_zone       = "${var.aws_region}${substr(each.key, -1, 1)}"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.team_name}-public-subnet-${each.key}"
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.private_subnets[each.key]
  availability_zone       = "${var.aws_region}${substr(each.key, -1, 1)}"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.team_name}-private-subnet-${each.key}"
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

# NAT gateway, its Elastic IP and the private default route only exist when
# var.enable_nat_gateway is true (about $32/month + data while it runs).
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
