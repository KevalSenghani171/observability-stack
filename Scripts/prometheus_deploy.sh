#!/bin/bash

echo -e "\n"

set -e

echo "Current working directory:"
pwd

echo "Listing files:"
ls -l
echo -e "\n"



echo -e "\n"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo -e "\n"
cd prometheus 
ls -l

helm upgrade --install prometheus prometheus-community/prometheus -f values.yaml  -n devops-tools    

kubectl get all -n  devops-tools 


sleep 45
echo -e "\n"


if [ $? -eq 0 ]; then
   echo "Job Ended Succesfully"
else
   exit
fi
