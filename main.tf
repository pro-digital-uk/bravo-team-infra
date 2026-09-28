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

terraform {
  backend "s3" {
    bucket = "terraform-state-493245399435"
    key    = "dev/terraform.tfstate"
    region = "eu-west-2"
  }
}


# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------
locals {
  # AZ suffix => CIDR block
  public_subnets = {
    "2a" = "10.0.0.0/20"
    "2b" = "10.0.16.0/20"
  }

  private_subnets = {
    "2a" = "10.0.32.0/20"
    "2b" = "10.0.48.0/20"
  }

  instance_type = "t3.micro"
}


# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "team-alpha-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "team-alpha-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "team-alpha-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "team-alpha-private-rt"
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = "eu-west-${each.key}"
  map_public_ip_on_launch = true

  tags = {
    Name = "team-alpha-public-subnet-${each.key}"
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = "eu-west-${each.key}"
  map_public_ip_on_launch = false

  tags = {
    Name = "team-alpha-private-subnet-${each.key}"
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

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["2a"].id

  tags = {
    Name = "team-alpha-nat-gateway"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "team-alpha-nat-eip"
  }
  depends_on = [aws_internet_gateway.main]
}

# Take over the VPC's default security group and strip all rules from it,
# so nothing can accidentally rely on it.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "team-alpha-default-sg-locked"
  }
}

# -----------------------------------------------------------------------------
# VPC flow logs
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/vpc/team-alpha-vpc/flow-logs"
  retention_in_days = 30
}

data "aws_iam_policy_document" "vpc_flow_logs_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name               = "team-alpha-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume.json
}

data "aws_iam_policy_document" "vpc_flow_logs" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"]
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name   = "vpc-flow-logs-to-cloudwatch"
  role   = aws_iam_role.vpc_flow_logs.id
  policy = data.aws_iam_policy_document.vpc_flow_logs.json
}

resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn

  tags = {
    Name = "team-alpha-vpc-flow-log"
  }
}


# -----------------------------------------------------------------------------
# EC2
# -----------------------------------------------------------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_security_group" "web" {
  name        = "team-alpha-web-sg"
  description = "Allow HTTP inbound and all outbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "team-bravo-public-web-sg"
  }
}

resource "aws_security_group" "private_web" {
  name        = "team-bravo-private-web-sg"
  description = "Allow HTTP from the public web SG only, and all outbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from public web instances"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "team-bravo-private-web-sg"
  }
}

# 4. Instance role so both instances can be reached via SSM Session Manager
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_ssm" {
  name               = "team-bravo-ec2-ssm"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "team-bravo-ec2-ssm"
  role = aws_iam_role.ec2_ssm.name
}

resource "aws_instance" "web_2a_public" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = local.instance_type
  user_data                   = file("${path.module}/user-data.sh")
  user_data_replace_on_change = true
  subnet_id                   = aws_subnet.public["2a"].id
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name

  # Require IMDSv2 (session tokens) for the instance metadata service
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "team-bravo-public-2a-web"
  }

  # Don't replace running instances every time AWS publishes a new AMI.
  # Roll to the latest deliberately with: terraform apply -replace=<address>
  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_instance" "web_2a_private" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = local.instance_type
  subnet_id              = aws_subnet.private["2a"].id
  vpc_security_group_ids = [aws_security_group.private_web.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name

  # Require IMDSv2 (session tokens) for the instance metadata service
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "team-bravo-private-2a-web"
  }

  # Don't replace running instances every time AWS publishes a new AMI.
  # Roll to the latest deliberately with: terraform apply -replace=<address>
  lifecycle {
    ignore_changes = [ami]
  }
}

