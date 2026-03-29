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

helm upgrade --install jaeger jaegertracing/jaeger -n observability -f values.yaml -f overrides/values.yaml


kubectl get all -n  observability 

sleep 45
echo -e "\n"


if [ $? -eq 0 ]; then
   echo "Job Ended Succesfully"
else
   exit
fi
