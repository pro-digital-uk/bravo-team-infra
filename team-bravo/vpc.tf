# -----------------------------------------------------------------------------
# VPC - network, NAT, default SG lockdown, flow logs
# -----------------------------------------------------------------------------

#Bravo team VPC - KA
resource "aws_vpc" "bravo" {
  cidr_block           = var.bravo_vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.team_name}-vpc"
  }
}

resource "aws_internet_gateway" "bravo" {
  vpc_id = aws_vpc.bravo.id

  tags = {
    Name = "${var.team_name}-igw"
  }
}

resource "aws_route_table" "bravo_public" {
  vpc_id = aws_vpc.bravo.id

  route {
    cidr_block = var.security_group_outbound_cidr_blocks[0]
    gateway_id = aws_internet_gateway.bravo.id
  }

  tags = {
    Name = "${var.team_name}-public-rt"
  }
}

resource "aws_route_table" "bravo_private" {
  vpc_id = aws_vpc.bravo.id

  tags = {
    Name = "${var.team_name}-private-rt"
  }
}

resource "aws_subnet" "bravo_public" {
  for_each = local.bravo_public_subnets

  vpc_id                  = aws_vpc.bravo.id
  cidr_block              = local.bravo_public_subnets[each.key]
  availability_zone       = "${var.aws_region}${substr(each.key, -1, 1)}"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.team_name}-public-subnet-${each.key}"
  }
}

resource "aws_subnet" "bravo_private" {
  for_each = local.bravo_private_subnets

  vpc_id                  = aws_vpc.bravo.id
  cidr_block              = local.bravo_private_subnets[each.key]
  availability_zone       = "${var.aws_region}${substr(each.key, -1, 1)}"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.team_name}-private-subnet-${each.key}"
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

