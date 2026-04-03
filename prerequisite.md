## ⚡ Kubernetes Cluster Setup on EC2 (kubeadm + Terraform)

This guide provisions a standalone Kubernetes cluster on AWS EC2 using Terraform and kubeadm, and configures remote access via `kubectl`.

---

### 🚀 1. Clone Repository

```bash
git clone https://github.com/KevalSenghani171/observability-stack.git
cd observability-stack
```

---

### 🛠️ 2. Install Required Tools

```bash
# AWS CLI
chmod +x ./install_awscli.sh && ./install_awscli.sh
aws configure

# kubectl
chmod +x ./install_kubectl.sh && ./install_kubectl.sh

# Terraform
chmod +x ./install_terraform.sh && ./install_terraform.sh
```

---

### ☁️ 3. Provision Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

---

### 🔗 4. Join Worker Nodes

On **master node**, generate join command:

```bash
kubeadm token create --print-join-command
```

Run the generated command on **each worker node**:

```bash
sudo kubeadm join <MASTER_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash <HASH>
```

---

### ✅ 5. Verify Cluster

```bash
kubectl get nodes
```

---

### ⚙️ 6. Configure kubeconfig (Master)

```bash
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Export for remote access
sudo cp /etc/kubernetes/admin.conf /home/ubuntu/kubeconfig
sudo chown ubuntu:ubuntu /home/ubuntu/kubeconfig
```

---

### 🌐 7. Access Cluster from Local / Another EC2

```bash
chmod 400 <pem-file>

mkdir -p ~/.kube
scp -i <pem-file> ubuntu@<MASTER_PUBLIC_IP>:/home/ubuntu/kubeconfig ~/.kube/config
```

---

### 🧪 8. Validate Access

```bash
kubectl get nodes
```
---
### 🧪 9. Install EBS Drivers
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update
helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver -n kube-system

### 🧪 10. Create StorageClass
kubectl apply -f storageclass-ebs.yaml

### 🧪 11. Create DockerHub Secrets for pulling image used in gocd agent
kubectl create secret docker-registry dockerhub-creds \
  --docker-username={username} \
  --docker-password={password}

### 🧪 11. Create Grafana Mysql Secrets for connecting to backend Grafana DB
kubectl create secret generic grafana-mysql \
  --from-literal=MYSQL_USER={user} \
  --from-literal=MYSQL_PASSWORD='{Password}' \
  --from-literal=MYSQL_HOST={Host}:3306 -n devops-tools
