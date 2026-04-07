const express = require('express');
const client = require('prom-client');
const pyroscope = require('@pyroscope/nodejs');

pyroscope.init({
  serverAddress: 'http://pyroscope:4040',
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
