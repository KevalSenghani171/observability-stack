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
helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/
helm repo update

echo -e "\n"
cd awx-operator 
ls -l

helm upgrade --install awx awx-operator/awx-operator -f values.yaml  -n awx    

kubectl get all -n  awx 

sleep 45
echo -e "\n"


if [ $? -eq 0 ]; then
   echo "Job Ended Succesfully"
else
   exit
fi
