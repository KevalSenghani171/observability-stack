
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.default.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.default.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "kubernetes_sg" {
  vpc_id = aws_vpc.default.id
  name   = "kubernetes-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_iam_instance_profile" "existing" {
  name = "devops-aws"
}

resource "aws_instance" "kubernetes_nodes" {
  count         = 3
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.kubernetes_sg.id]
  key_name      = var.key_name
  iam_instance_profile = data.aws_iam_instance_profile.existing.name

  tags = {
    Name = "kubernetes-node-${count.index + 1}"
  }
}