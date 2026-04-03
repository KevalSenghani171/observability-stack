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
    description = "Kubernetes API"
    from_port   = 10250
    to_port     = 10250
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


resource "aws_instance" "master" {
  ami           = var.ami_id
  instance_type = var.instance_type

  # Use first subnet from default VPC
  subnet_id = data.aws_subnets.default.ids[0]

  vpc_security_group_ids = [aws_security_group.kubernetes_sg.id]
  key_name               = var.key_name
  iam_instance_profile   = data.aws_iam_instance_profile.existing.name

  associate_public_ip_address = true
  user_data = <<-EOF
#!/bin/bash
set -e
exec > /var/log/user-data.log 2>&1

# ------------------------
# SYSTEM PREP
# ------------------------
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

modprobe overlay
modprobe br_netfilter

cat <<EOT > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOT

sysctl -p /etc/sysctl.d/k8s.conf

# ------------------------
# CONTAINERD
# ------------------------
apt update -y
apt install -y containerd curl apt-transport-https ca-certificates

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

# ------------------------
# KUBERNETES
# ------------------------
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /" \
> /etc/apt/sources.list.d/kubernetes.list

apt update
apt install -y kubelet kubeadm kubectl
systemctl enable kubelet

# ------------------------
# INIT CLUSTER
# ------------------------
kubeadm init --pod-network-cidr=192.168.0.0/16

# kubeconfig
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# install calico
su - ubuntu -c "kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/calico.yaml"


EOF

  tags = {
    Name = "master-node"
  }
}
# EC2 Instances
resource "aws_instance" "worker" {
  count         = 4
  ami           = var.ami_id
  instance_type = var.instance_type

  # Use first subnet from default VPC
  subnet_id = data.aws_subnets.default.ids[0]

  vpc_security_group_ids = [aws_security_group.kubernetes_sg.id]
  key_name               = var.key_name
  iam_instance_profile   = data.aws_iam_instance_profile.existing.name

  associate_public_ip_address = true
  depends_on = [aws_instance.master]

  user_data = <<-EOF
#!/bin/bash
set -e
exec > /var/log/user-data.log 2>&1

# ------------------------
# SYSTEM PREP
# ------------------------
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

modprobe overlay
modprobe br_netfilter

cat <<EOT > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOT

sysctl -p /etc/sysctl.d/k8s.conf

# ------------------------
# CONTAINERD
# ------------------------
apt update -y
apt install -y containerd curl apt-transport-https ca-certificates

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

# ------------------------
# KUBERNETES
# ------------------------
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /" \
> /etc/apt/sources.list.d/kubernetes.list

apt update
apt install -y kubelet kubeadm
systemctl enable kubelet

EOF

  tags = {
    Name = "worker-node-${count.index + 1}"
  }
}