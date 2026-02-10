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
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

echo -e "\n"
cd ingress-nginx
ls -l


helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -f values.yaml  -n ingress-nginx 

kubectl get all -n  ingress-nginx 

sleep 45
echo -e "\n"


if [ $? -eq 0 ]; then
   echo "Job Ended Succesfully"
else
   exit
fi
