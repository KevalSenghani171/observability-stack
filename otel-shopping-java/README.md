# OTel Shopping Demo (Java + Docker)

A small Spring Boot shopping API demonstrating **manual OpenTelemetry spans** for product pagination, cart operations, checkout, and direct purchase. Uses an in-memory H2 database and a local OpenTelemetry Collector. This is a learning/demo app, not a production payment system.

## Requirements
- Docker Engine and Docker Compose plugin

## Run
```bash
docker compose up --build
```
API: http://localhost:8080  
The Collector receives OTLP traces on 4317/4318 and prints them to its debug exporter logs:
```bash
docker compose logs -f otel-collector
```

## API examples

List products (paginated):
```bash
curl 'http://localhost:8080/api/products?page=0&size=5'
```

Add two units of product 1 to cart `cart-123`:
```bash
curl -X POST http://localhost:8080/api/cart/cart-123/items \
  -H 'Content-Type: application/json' \
  -d '{"productId":1,"quantity":2}'
```

View cart:
```bash
curl http://localhost:8080/api/cart/cart-123
```

Checkout:
```bash
curl -X POST http://localhost:8080/api/cart/cart-123/checkout
```

Buy directly (adds item then checks out):
```bash
curl -X POST 'http://localhost:8080/api/buy/2?quantity=1'
```

## Manual spans
`ShoppingService` creates spans:
- `catalog.list_products`
- `cart.add_item`
- `cart.view`
- `checkout.process`
- `checkout.validate_and_reserve_item` (child span per cart line)

Spans include useful low-cardinality operation attributes. Cart IDs and product IDs are included only to make the demo easy to follow; avoid high-cardinality or personal/sensitive identifiers in production telemetry. No PAN, account numbers, credentials, or payment secrets should be added to span attributes.

## Trace propagation
The SDK is configured with W3C Trace Context propagation. The demo's business spans are exported over OTLP gRPC. For inbound HTTP server/client spans and automatic context propagation, add the OpenTelemetry Java agent or instrument Spring MVC using the OTel instrumentation libraries; this project intentionally focuses on manual business spans.

## Notes
- The `PAID_DEMO` status is simulated. No real payment is processed.
- H2 is in-memory; data resets when the container restarts.
- The demo has no authentication, authorization, or real payment security controls.


## Deploy to Kubernetes with Helm

The chart is in `helm/otel-shopping`. It deploys the shopping API, a ClusterIP Service,
and (by default) a small OpenTelemetry Collector that receives OTLP/gRPC traces and
prints them to its logs. It is a demo configuration; use a persistent trace backend
such as Jaeger or Tempo for retained/queryable traces.

### 1. Build and publish the application image

From the project root, build the image and push it to a registry reachable by your cluster:

```bash
docker build -t YOUR_REGISTRY/otel-shopping:1.0.0 .
docker push YOUR_REGISTRY/otel-shopping:1.0.0
```

For a local single-node Kubernetes cluster, you can instead build/load the image into
that cluster and keep `image.repository=otel-shopping` with `image.pullPolicy=IfNotPresent`.

### 2. Install

```bash
helm upgrade --install otel-shopping ./helm/otel-shopping \
  --namespace demo --create-namespace \
  --set image.repository=YOUR_REGISTRY/otel-shopping \
  --set image.tag=1.0.0
```

Check the workloads:

```bash
kubectl get pods,svc -n demo
kubectl logs -n demo deploy/otel-shopping-otel-shopping-collector -f
```

### 3. Call the API

Forward the Service locally:

```bash
kubectl port-forward -n demo svc/otel-shopping-otel-shopping 8080:8080
```

Then use the API examples above, for example:

```bash
curl 'http://localhost:8080/api/products?page=0&size=5'
```

### 4. Remove

```bash
helm uninstall otel-shopping -n demo
```

The chart defaults to one application replica and an in-memory H2 database. Data is
lost when the application pod restarts. The collector's debug exporter is intended
for learning and troubleshooting, not long-term trace storage.
