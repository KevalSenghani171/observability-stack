#!/bin/bash

echo -e "\n"

set -e

# mkdir -p ~/.kube
# echo "$KUBECONFIG_DATA" > ~/.kube/config
# chmod 600 ~/.kube/config

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
cd grafana 

envssubst < grafana-resources/datasources/datasource.yaml.tpl >> grafana-resources/datasources/datasource.yaml
rm grafana-resources/datasources/datasource.yaml.tpl
ls -l
echo ".....Grafana......"
# kubectl create secret generic grafana-mysql -n devops-tools --from-literal=password="$GRAFANA_DB_PASSWORD" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install grafana grafana/grafana -f values.yaml -f override/values.yaml  -n devops-tools    

kubectl get all -n  devops-tools 

sleep 45
echo -e "\n"
echo ".....Copy dashboards......"
grafana_pod=`kubectl -n devops-tools get po -l app.kubernetes.io/instance=grafana -o=jsonpath='{.items[0].metadata.name}'`


kubectl -n devops-tools exec -it ${grafana_pod} -c grafana -- rm -rf /var/lib/grafana/dashboards/OBS
kubectl -n devops-tools cp grafana-resources/dashboards/OBS ${grafana_pod}:/var/lib/grafana/dashboards/ -c grafana
kubectl -n devops-tools exec -it ${grafana_pod} -c grafana -- curl -u admin:Admin@123 -H -s -X POST "http://localhost:3000/api/admin/provisioning/dashboards/reload"


kubectl -n devops-tools exec -it ${grafana_pod} -c grafana -- rm -rf /etc/grafana/provisioning/datasources 
kubectl -n devops-tools cp grafana-resources/datasources ${grafana_pod}:/etc/grafana/provisioning -c grafana
kubectl -n devops-tools exec -it ${grafana_pod} -c grafana -- curl -u admin:Admin@123 -H -s -X POST "http://localhost:3000/api/admin/provisioning/datasources/reload"

kubectl -n devops-tools exec -it ${grafana_pod} -c grafana -- rm -rf /etc/grafana/provisioning/alerting
kubectl -n devops-tools cp grafana-resources/alerting ${grafana_pod}:/etc/grafana/provisioning -c grafana
kubectl -n devops-tools exec -it ${grafana_pod} -c grafana -- curl -u admin:Admin@123 -H -s -X POST "http://localhost:3000/api/admin/provisioning/alerting/reload"



if [ $? -eq 0 ]; then
   echo "Job Ended Succesfully"
else
   exit
fi
