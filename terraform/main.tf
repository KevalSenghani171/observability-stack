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
#!/bin/bash
set -e

apt update -y
apt install -y containerd curl apt-transport-https ca-certificates python3

systemctl enable containerd
systemctl start containerd

mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

apt update
apt install -y kubelet kubeadm kubectl
systemctl enable kubelet

# SYSTEM FIX
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

cat <<EOF2 > /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward=1
EOF2

sysctl --system

# INIT
kubeadm init \
  --apiserver-advertise-address=$(hostname -I | awk '{print $1}') \
  --pod-network-cidr=192.168.0.0/16

# kubeconfig
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Calico
sleep 30
su - ubuntu -c "kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/calico.yaml"

# Generate join command (NO EXPIRY)
kubeadm token create --ttl 0 --print-join-command > /join.sh
chmod +x /join.sh

# Serve it over HTTP
cd /
nohup python3 -m http.server 8080 &
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

apt update -y
apt install -y containerd curl apt-transport-https ca-certificates

systemctl enable containerd
systemctl start containerd

mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

apt update
apt install -y kubelet kubeadm
systemctl enable kubelet

# SYSTEM FIX
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

cat <<EOF2 > /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward=1
EOF2

sysctl --system

# WAIT FOR MASTER API + HTTP
sleep 240

# Fetch join command dynamically
curl http://${aws_instance.master.private_ip}:8080/join.sh -o /join.sh

chmod +x /join.sh
bash /join.sh
EOF

  tags = {
    Name = "worker-node-${count.index + 1}"
  }
}