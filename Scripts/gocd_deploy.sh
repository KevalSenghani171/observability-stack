#!/bin/bash

echo -e "\n"

set -e

echo "Current working directory:"
pwd

echo "Listing files:"
ls -l
echo -e "\n"



echo -e "\n"
helm repo add gocd https://gocd.github.io/helm-chart
helm repo update

echo -e "\n"
cd gocd 
ls -l

helm upgrade --install gocd gocd/gocd -n gocd -f values.yaml -f override/values.yaml -n gocd    

kubectl get all -n  gocd 


sleep 45
echo -e "\n"


if [ $? -eq 0 ]; then
   echo "Job Ended Succesfully"
else
   exit
fi
