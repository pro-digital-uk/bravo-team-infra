# -----------------------------------------------------------------------------
# EC2 - AMI, security groups, SSM instance role, instances
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

# Instance role so both instances can be reached via SSM Session Manager
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
