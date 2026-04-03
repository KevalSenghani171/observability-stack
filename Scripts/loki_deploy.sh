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
cd loki 
ls -l

helm upgrade --install loki grafana/loki -f values.yaml -f override/values.yaml -n devops-tools    

kubectl get all -n  devops-tools 


sleep 45
echo -e "\n"
echo ".....Copy dashboards......"


if [ $? -eq 0 ]; then
   echo "Job Ended Succesfully"
else
   exit
fi
