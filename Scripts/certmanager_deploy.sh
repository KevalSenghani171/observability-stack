#!/bin/bash

echo -e "\n"


set -e

echo "Current working directory:"
pwd

echo "Listing files:"
ls -l
echo -e "\n"

echo "Using latest values.yaml from Git"

echo -e "\n"
helm repo add jetstack https://charts.jetstack.io
helm repo update


echo -e "\n"
cd cert-manager
ls -l
  
helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true -f values.yaml
kubectl get all -n  cert-manager

sleep 45
echo -e "\n"


if [ $? -eq 0 ]; then
   echo "Job Ended Succesfully"
else
   exit
fi
