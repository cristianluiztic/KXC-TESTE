-- Criar tabela de exemplo
CREATE TABLE IF NOT EXISTS requests (
    id SERIAL PRIMARY KEY,
    path VARCHAR(255),
    method VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Criar índice para melhor performance
CREATE INDEX IF NOT EXISTS idx_requests_created_at ON requests(created_at);
