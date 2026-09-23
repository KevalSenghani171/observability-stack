#!/bin/bash

set -e

echo "Updating system..."
sudo apt update -y
sudo apt install -y curl unzip

echo "Downloading AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

echo "Unzipping package..."
unzip -o awscliv2.zip

echo "Installing AWS CLI..."
sudo ./aws/install --update

echo "Cleaning up..."
rm -rf aws awscliv2.zip

echo "AWS CLI Installed Successfully!"
aws --version
