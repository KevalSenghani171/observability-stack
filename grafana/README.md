# Grafana

Grafana is a popular open-source platform for visualization, monitoring, and analytics. It enables users to query, visualize, and create alerts on metrics, logs, and traces from multiple data sources, transforming raw data into interactive, real-time dashboards.

---

## 🚀 Setup & Access

```bash
# Step 1: Configure values
# Update overrides/values.yaml with required configurations

# Step 2: Deploy Grafana via GOCD
# Run: Grafana-deploy pipeline

# Step 3: Get service details
kubectl get svc -n devops-tools

## 🚀 Open Grafana in your browser
http://<node_public_ip>:<nodePort>


