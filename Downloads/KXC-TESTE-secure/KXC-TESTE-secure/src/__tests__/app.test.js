'use strict';

const request    = require('supertest');
const { createApp } = require('../app');

const mockPool = {
  on:    jest.fn(),
  query: jest.fn(),
};

const app = createApp(mockPool);

beforeEach(() => {
  jest.clearAllMocks();
});

describe('GET /health', () => {
  it('retorna 200 com status healthy', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('healthy');
    expect(res.body.timestamp).toBeDefined();
  });
});

describe('GET /ready', () => {
  it('retorna 200 quando banco responde', async () => {
    mockPool.query.mockResolvedValueOnce({ rows: [] });
    const res = await request(app).get('/ready');
    expect(res.status).toBe(200);
    expect(res.body.ready).toBe(true);
  });

  it('retorna 503 quando banco falha', async () => {
    mockPool.query.mockRejectedValueOnce(new Error('connection refused'));
    const res = await request(app).get('/ready');
    expect(res.status).toBe(503);
    expect(res.body.ready).toBe(false);
  });
});

describe('GET /', () => {
  it('retorna mensagem de API OK', async () => {
    const res = await request(app).get('/');
    expect(res.status).toBe(200);
    expect(res.body.message).toBe('API OK!');
  });
});

describe('POST /requests', () => {
  it('retorna 400 quando path ou method estão ausentes', async () => {
    const res = await request(app).post('/requests').send({});
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/path and method/);
  });

  it('salva a requisição e retorna 201', async () => {
    mockPool.query.mockResolvedValueOnce({
      rows: [{ id: 1, path: '/foo', method: 'GET', created_at: new Date() }],
    });
    const res = await request(app)
      .post('/requests')
      .send({ path: '/foo', method: 'GET' });
    expect(res.status).toBe(201);
    expect(res.body.data.path).toBe('/foo');
  });

  it('retorna 500 quando o banco falha', async () => {
    mockPool.query.mockRejectedValueOnce(new Error('db error'));
    const res = await request(app)
      .post('/requests')
      .send({ path: '/foo', method: 'GET' });
    expect(res.status).toBe(500);
  });
});

describe('GET /requests', () => {
  it('lista requisições com limit padrão 10', async () => {
    mockPool.query.mockResolvedValueOnce({ rows: [] });
    const res = await request(app).get('/requests');
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([]);
    expect(mockPool.query).toHaveBeenCalledWith(
      expect.stringContaining('SELECT'),
      [10],
    );
  });

  it('cap de 100 no limit', async () => {
    mockPool.query.mockResolvedValueOnce({ rows: [] });
    await request(app).get('/requests?limit=9999');
    expect(mockPool.query).toHaveBeenCalledWith(expect.anything(), [100]);
  });
});
