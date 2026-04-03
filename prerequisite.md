## ⚡ Prerequisites

Before getting started, install and configure the required tools:

```bash
# Install AWS CLI
chmod +x ./install_awscli.sh
./install_awscli.sh

# Configure AWS credentials

aws configure

# Install kubectl
chmod +x ./install_kubectl.sh
./install_kubectl.sh

# Install Terraform
chmod +x ./install_terraform.sh
./install_terraform.sh

## ⚡ Quick Start

### 1️⃣ Clone the Repository
```bash
git clone https://github.com/KevalSenghani171/observability-stack.git
cd observability-stack


cd terraform
terraform init
terraform apply
