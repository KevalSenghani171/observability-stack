# Jaeger

# Jaeger is an open-source, cloud-native distributed tracing platform used to monitor, troubleshoot, and optimize complex microservices-based applications.


# Steps 1: added overrides/values.yaml for additional parameter optimisation.

# Steps 2: Run Jaeger-Tracing-deploy Pipeline in GOCD.

# Steps 3: kubectl port-forward --namespace observability {JAEGER_POD} 16686:16686 --address 0.0.0.0