const express = require('express');

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0';

app.get('/', (_req, res) => {
  res.type('text/plain').send('Aplicação executando no OpenShift com sucesso!');
});

app.get('/status', (_req, res) => {
  res.json({
    status: 'online',
    ambiente: process.env.APP_ENVIRONMENT || 'OpenShift',
  });
});

app.listen(PORT, HOST, () => {
  console.log(`Servidor iniciado em http://${HOST}:${PORT}`);
});
