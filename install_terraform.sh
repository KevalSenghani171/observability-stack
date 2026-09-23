#!/bin/bash

set -e

echo "Updating system..."
sudo apt update -y

echo "Installing required packages..."
sudo apt install -y gnupg software-properties-common curl

echo "Adding HashiCorp GPG key..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | \
sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "Adding HashiCorp repository..."
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list

echo "Updating package list..."
sudo apt update -y

echo "Installing Terraform..."
sudo apt install -y terraform

echo "Terraform version:"
terraform -version

echo "Enabling autocomplete..."
terraform -install-autocomplete

echo "Terraform installation completed successfully!"
