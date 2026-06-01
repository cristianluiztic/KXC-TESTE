'use strict';

const { Pool }      = require('pg');
const http          = require('http');
const { createApp } = require('./app');

const pool = new Pool({
  user:     process.env.DB_USER,
  host:     process.env.DB_HOST,
  database: process.env.DB_DATABASE,
  password: process.env.DB_PASSWORD,
  port:     parseInt(process.env.DB_PORT || '5432', 10),
  ssl:      { rejectUnauthorized: false },
  max:               10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => {
  console.error('Unexpected error on idle DB client', err);
});

const port = process.env.API_PORT || 3000;
const app  = createApp(pool);

const server = http.createServer(app);

server.listen(port, () => {
  console.log(`API iniciada. Escutando PORT ${port}`);
  console.log(`Ambiente: ${process.env.NODE_ENV || 'development'}`);
  if (process.env.NODE_ENV !== 'production') {
    console.log(`Banco de dados: ${process.env.DB_HOST}:${process.env.DB_PORT || 5432}/${process.env.DB_DATABASE}`);
  }
});

process.on('SIGTERM', async () => {
  console.log('SIGTERM recebido. Encerrando servidor...');
  server.close(async () => {
    await pool.end();
    console.log('Pool de conexões encerrado. Servidor encerrado.');
    process.exit(0);
  });
});
