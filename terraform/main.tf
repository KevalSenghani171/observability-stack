# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get subnets inside default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group
resource "aws_security_group" "kubernetes_sg" {
  name   = "kubernetes-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Node to Node"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Existing Instance Profile
data "aws_iam_instance_profile" "existing" {
  name = "devops-aws"
}

# EC2 Instances
resource "aws_instance" "kubernetes_nodes" {
  count         = 3
  ami           = var.ami_id
  instance_type = var.instance_type

  # Use first subnet from default VPC
  subnet_id = data.aws_subnets.default.ids[0]

  vpc_security_group_ids = [aws_security_group.kubernetes_sg.id]
  key_name               = var.key_name
  iam_instance_profile   = data.aws_iam_instance_profile.existing.name

  associate_public_ip_address = true

  tags = {
    Name = "kubernetes-node-${count.index + 1}"
  }
}