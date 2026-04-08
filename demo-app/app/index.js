const express = require('express');
const client = require('prom-client');
const pyroscope = require('@pyroscope/nodejs');

const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-otlp-http');

const sdk = new NodeSDK({
  metricExporter: new OTLPMetricExporter({
    url: 'http://alloy.devops-tools.svc.cluster.local:4318/v1/metrics',
  }),
});

sdk.start();

pyroscope.init({
  serverAddress: 'http://pyroscope.devops-tools.svc.cluster.local:4040',
  appName: 'my-app',
});

const app = express();

client.collectDefaultMetrics();

app.get('/', (req, res) => {
  res.send('Hello Observability 🚀');
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});

app.listen(3300, () => console.log('App running'));
