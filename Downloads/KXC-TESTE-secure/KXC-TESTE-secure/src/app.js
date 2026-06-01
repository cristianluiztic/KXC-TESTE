'use strict';

const express = require('express');

function createApp(pool) {
  const app = express();
  let requestCount = 0;

  app.use(express.json());

  app.use((req, res, next) => {
    requestCount++;
    next();
  });

  app.get('/health', (req, res) => {
    res.json({ status: 'healthy', timestamp: new Date().toISOString() });
  });

  app.get('/ready', async (req, res) => {
    try {
      await pool.query('SELECT 1');
      res.json({ ready: true });
    } catch (e) {
      console.error('Readiness check failed', e);
      res.status(503).json({ ready: false });
    }
  });

  app.get('/', (req, res) => {
    res.json({
      message:     'API OK!',
      request_id:  requestCount,
      timestamp:   new Date().toISOString(),
      environment: process.env.NODE_ENV || 'development',
    });
  });

  app.get('/connect', async (req, res) => {
    try {
      const result  = await pool.query('SELECT version()');
      const version = result.rows[0].version;
      res.json({ message: 'Conectado ao banco', version, request_id: requestCount, timestamp: new Date().toISOString() });
    } catch (e) {
      console.error('Erro ao conectar ao banco', e);
      res.status(500).json({ message: 'Erro ao se conectar ao banco', request_id: requestCount, timestamp: new Date().toISOString() });
    }
  });

  app.post('/requests', async (req, res) => {
    const { path, method } = req.body;

    if (!path || !method) {
      return res.status(400).json({ error: 'path and method são obrigatórios', request_id: requestCount });
    }

    try {
      const result = await pool.query(
        'INSERT INTO requests (path, method) VALUES ($1, $2) RETURNING *',
        [path, method],
      );
      res.status(201).json({ message: 'Requisição salva com sucesso', data: result.rows[0], request_id: requestCount });
    } catch (e) {
      console.error('Erro ao salvar requisição', e);
      res.status(500).json({ error: 'Erro ao salvar requisição', request_id: requestCount });
    }
  });

  app.get('/requests', async (req, res) => {
    try {
      const limit  = Math.min(parseInt(req.query.limit || '10', 10), 100);
      const result = await pool.query('SELECT * FROM requests ORDER BY created_at DESC LIMIT $1', [limit]);
      res.json({ data: result.rows, count: result.rows.length, request_id: requestCount });
    } catch (e) {
      console.error('Erro ao listar requisições', e);
      res.status(500).json({ error: 'Erro ao listar requisições', request_id: requestCount });
    }
  });

  app.use((err, req, res, _next) => {
    console.error(err);
    const isProd = process.env.NODE_ENV === 'production';
    res.status(500).json({
      error: 'Internal Server Error',
      ...(isProd ? {} : { message: err.message }),
      request_id: requestCount,
    });
  });

  return app;
}

module.exports = { createApp };
