const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.send('Hello from Auto-Instrumented App!');
});

app.listen(3300, () => {
  console.log('App running on port 3300');
});