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
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

echo -e "\n"
cd mimir-distributed  
ls -l

helm upgrade --install mimir grafana/mimir-distributed -f values.yaml -f small.yaml -n devops-tools    

kubectl get all -n  devops-tools 

sleep 45
echo -e "\n"


if [ $? -eq 0 ]; then
   echo "Job Ended Succesfully"
else
   exit
fi
