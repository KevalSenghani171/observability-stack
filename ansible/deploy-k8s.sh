#!/bin/bash

### ======== USER VARIABLES (EDIT THIS) =========
MASTER_PUBLIC_IP="13.234.11.125"
WORKER1_PUBLIC_IP="3.110.93.187"
WORKER2_PUBLIC_IP="13.200.14.100"

MASTER_PRIVATE_IP="172.31.24.20"
WORKER1_PRIVATE_IP="172.31.19.7"
WORKER2_PRIVATE_IP="172.31.26.188"

SSH_KEY="devops-aws.pem"
SSH_USER="ubuntu"
CLUSTER_NAME="devops-aws-cluster"
K8S_VERSION="v2.24.0"   # Kubespray version
### =============================================

set -e

echo "Installing dependencies..."
sudo apt update -y
sudo apt install -y python3-pip git
pip3 install --upgrade pip
pip3 install ansible

echo "Cloning Kubespray..."
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
git checkout ${K8S_VERSION}
pip3 install -r requirements.txt

echo "Creating inventory..."
cp -rfp inventory/sample inventory/${CLUSTER_NAME}

cat > inventory/${CLUSTER_NAME}/hosts.yaml <<EOF
all:
  hosts:
    master:
      ansible_host: ${MASTER_PUBLIC_IP}
      ip: ${MASTER_PRIVATE_IP}
      access_ip: ${MASTER_PRIVATE_IP}
    worker1:
      ansible_host: ${WORKER1_PUBLIC_IP}
      ip: ${WORKER1_PRIVATE_IP}
      access_ip: ${WORKER1_PRIVATE_IP}
    worker2:
      ansible_host: ${WORKER2_PUBLIC_IP}
      ip: ${WORKER2_PRIVATE_IP}
      access_ip: ${WORKER2_PRIVATE_IP}

  children:
    kube_control_plane:
      hosts:
        master:
    kube_node:
      hosts:
        worker1:
        worker2:
    etcd:
      hosts:
        master:
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
EOF

echo "Starting Kubernetes deployment..."
ansible-playbook -i inventory/${CLUSTER_NAME}/hosts.yaml \
  --user=${SSH_USER} \
  --private-key=../${SSH_KEY} \
  --become --become-user=root \
  cluster.yml

echo "Deployment Completed!"
echo "SSH into master and run: kubectl get nodes"