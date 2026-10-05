
resource "aws_security_group" "public" {
  name        = "${var.team_name}-web-sg"
  description = "Allow HTTP inbound and all outbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.security_group_outbound_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.security_group_outbound_cidr_blocks
  }

  tags = {
    Name = "${var.team_name}-${var.project_name}-public-sg"
  }
}

resource "aws_security_group" "private" {
  name        = "${var.team_name}-${var.project_name}-private-sg"
  description = "Allow HTTP from the public web SG only, and all outbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from public web instances"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.public.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.security_group_outbound_cidr_blocks
  }

  tags = {
    Name = "${var.team_name}-${var.project_name}-private-sg"
  }
}
