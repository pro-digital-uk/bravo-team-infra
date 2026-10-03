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

resource "aws_instance" "web_2a_public" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = local.instance_type
  user_data                   = file("${path.module}/user-data.sh")
  user_data_replace_on_change = true
  subnet_id                   = aws_subnet.public["2a"].id
  vpc_security_group_ids      = [aws_security_group.public_web.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name
  key_name                    = aws_key_pair.deployer.key_name

  # Require IMDSv2 (session tokens) for the instance metadata service
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "${var.team_name}-public-2a-web"
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
  key_name               = aws_key_pair.deployer.key_name

  # Require IMDSv2 (session tokens) for the instance metadata service
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "${var.team_name}-private-2a-web"
  }

  # Don't replace running instances every time AWS publishes a new AMI.
  # Roll to the latest deliberately with: terraform apply -replace=<address>
  lifecycle {
    ignore_changes = [ami]
  }
}
