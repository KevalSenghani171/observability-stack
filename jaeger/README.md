# Jaeger

Jaeger is an open-source, cloud-native distributed tracing platform used to monitor, troubleshoot, and optimize microservices-based applications.

---

## 🚀 Setup Steps

### Step 1: Configure Values
Update `overrides/values.yaml` with the required parameters and optimizations.

### Step 2: Deploy Jaeger
Run the **Jaeger-Tracing-deploy** pipeline in GOCD.

### Step 3: Access Jaeger UI
Forward the Jaeger UI port:

```bash
kubectl port-forward --namespace observability <JAEGER_POD> 16686:16686 --address 0.0.0.0