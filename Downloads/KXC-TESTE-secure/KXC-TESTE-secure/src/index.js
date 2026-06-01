'use strict';

const { Pool } = require('pg');
const express   = require('express');
const http      = require('http');

// FIX: Pool de conexões criado UMA VEZ na inicialização da aplicação
// Evita abrir/fechar conexão a cada request (esgotamento do RDS sob carga)
const pool = new Pool({
  user:     process.env.DB_USER,
  host:     process.env.DB_HOST,
  database: process.env.DB_DATABASE,
  password: process.env.DB_PASSWORD,
  port:     parseInt(process.env.DB_PORT || '5432', 10),
  ssl:      { rejectUnauthorized: false },
  // Pool sizing adequado para Fargate 256 CPU / 512 MB
  max:              10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

// Log de erros do pool sem derrubar o processo
pool.on('error', (err) => {
  console.error('Unexpected error on idle DB client', err);
});

(async () => {
  const app  = express();
  const port = process.env.API_PORT || 3000;
  let requestCount = 0;

  // Middleware
  app.use(express.json());

  // FIX: contador de requests (mover antes dos health checks para não inflar métricas internas)
  app.use((req, res, next) => {
    requestCount++;
    next();
  });

  // Health check — não toca no banco (usado pelo ALB)
  app.get('/health', (req, res) => {
    res.json({ status: 'healthy', timestamp: new Date().toISOString() });
  });

  // Readiness check — verifica conectividade com o banco
  app.get('/ready', async (req, res) => {
    try {
      await pool.query('SELECT 1');
      res.json({ ready: true });
    } catch (e) {
      // FIX: não expor mensagem de erro interno ao cliente
      console.error('Readiness check failed', e);
      res.status(503).json({ ready: false });
    }
  });

  // GET /
  app.get('/', (req, res) => {
    const response = {
      message:    'API OK!',
      request_id: requestCount,
      timestamp:  new Date().toISOString(),
      environment: process.env.NODE_ENV || 'development',
    };
    console.log(response);
    res.json(response);
  });

  // GET /connect — verificar conexão com banco
  app.get('/connect', async (req, res) => {
    try {
      const result  = await pool.query('SELECT version()');
      const version = result.rows[0].version;

      res.json({
        message:    'Conectado ao banco',
        version,
        request_id: requestCount,
        timestamp:  new Date().toISOString(),
      });
    } catch (e) {
      console.error('Erro ao conectar ao banco', e);
      // FIX: não expor e.message ao cliente em produção
      res.status(500).json({
        message:    'Erro ao se conectar ao banco',
        request_id: requestCount,
        timestamp:  new Date().toISOString(),
      });
    }
  });

  // POST /requests — salvar requisição no banco
  app.post('/requests', async (req, res) => {
    const { path, method } = req.body;

    if (!path || !method) {
      return res.status(400).json({
        error:      'path and method são obrigatórios',
        request_id: requestCount,
      });
    }

    try {
      const result = await pool.query(
        'INSERT INTO requests (path, method) VALUES ($1, $2) RETURNING *',
        [path, method],
      );

      res.status(201).json({
        message:    'Requisição salva com sucesso',
        data:       result.rows[0],
        request_id: requestCount,
      });
    } catch (e) {
      console.error('Erro ao salvar requisição', e);
      res.status(500).json({
        error:      'Erro ao salvar requisição',
        request_id: requestCount,
      });
    }
  });

  // GET /requests — listar requisições
  app.get('/requests', async (req, res) => {
    try {
      const limit  = Math.min(parseInt(req.query.limit || '10', 10), 100); // FIX: cap de 100
      const result = await pool.query(
        'SELECT * FROM requests ORDER BY created_at DESC LIMIT $1',
        [limit],
      );

      res.json({
        data:       result.rows,
        count:      result.rows.length,
        request_id: requestCount,
      });
    } catch (e) {
      console.error('Erro ao listar requisições', e);
      res.status(500).json({
        error:      'Erro ao listar requisições',
        request_id: requestCount,
      });
    }
  });

  // Handler de erros global
  // FIX: não expor stack trace em produção
  app.use((err, req, res, _next) => {
    console.error(err);
    const isProd = process.env.NODE_ENV === 'production';
    res.status(500).json({
      error:      'Internal Server Error',
      ...(isProd ? {} : { message: err.message }),
      request_id: requestCount,
    });
  });

  const server = http.createServer(app);

  server.listen(port, () => {
    console.log(`API iniciada. Escutando PORT ${port}`);
    console.log(`Ambiente: ${process.env.NODE_ENV || 'development'}`);
    // FIX: não logar host/porta do banco em produção
    if (process.env.NODE_ENV !== 'production') {
      console.log(`Banco de dados: ${process.env.DB_HOST}:${process.env.DB_PORT || 5432}/${process.env.DB_DATABASE}`);
    }
  });

  // Graceful shutdown — encerra pool de conexões antes de sair
  process.on('SIGTERM', async () => {
    console.log('SIGTERM recebido. Encerrando servidor...');
    server.close(async () => {
      await pool.end();
      console.log('Pool de conexões encerrado. Servidor encerrado.');
      process.exit(0);
    });
  });
})();
