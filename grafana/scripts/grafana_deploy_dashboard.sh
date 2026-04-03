#!/bin/bash

echo "Starting Grafana dashboard deployment..."

if [[ -z "$GRAFANA_ADMIN_USER" || -z "$GRAFANA_ADMIN_PASSWORD" ]]; then
  echo "Missing Grafana credentials"
  exit 1
fi

NAMESPACE=${DEPLOY_NS:-devops-tools}

pods=$(kubectl -n $NAMESPACE get pods -l app.kubernetes.io/name=grafana -o jsonpath='{.items[*].metadata.name}')

if [[ -z "$pods" ]]; then
  echo "No Grafana pods found"
  exit 1
fi

for pod in $pods; do
  echo "Deploying dashboards to $pod"

  kubectl cp dashboards/. $NAMESPACE/$pod:/var/lib/grafana/dashboards -c grafana

  kubectl exec -n $NAMESPACE $pod -c grafana --     curl -X POST http://localhost:3000/api/admin/provisioning/dashboards/reload     -u $GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD

  echo "Dashboards deployed to $pod"
done

echo "Deployment completed"
