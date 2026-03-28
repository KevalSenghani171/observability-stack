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
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

echo -e "\n"
cd jaeger
ls -l

helm install jaeger jaegertracing/jaeger -n observability --set allInOne.enabled=false --set collector.enabled=true --set query.enabled=true
    

kubectl get all -n  observability 

sleep 45
echo -e "\n"


if [ $? -eq 0 ]; then
   echo "Job Ended Succesfully"
else
   exit
fi
