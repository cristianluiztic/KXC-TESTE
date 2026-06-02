# Simple API - Arquitetura

## Diagrama da Infraestrutura

```
                                   Internet
                                      ↓
                          ┌───────────────────────┐
                          │   CloudFront (CDN)    │
                          │  (Opcional, Caching)  │
                          └───────────┬───────────┘
                                      ↓
                          ┌───────────────────────┐
                          │ Internet Gateway      │
                          └───────────┬───────────┘
                                      ↓
                    ┌─────────────────────────────────────┐
                    │         AWS VPC (10.0.0.0/16)       │
                    │                                       │
                    │  ┌────────────────────────────────┐  │
                    │  │   Public Subnets (2 AZs)       │  │
                    │  │  ┌──────────────────────────┐  │  │
                    │  │  │ Application Load Balancer│  │  │
                    │  │  │  (Health Checks: /health)│  │  │
                    │  │  └──────────────────────────┘  │  │
                    │  │  ┌──────────────────────────┐  │  │
                    │  │  │   NAT Gateway (1 per AZ) │  │  │
                    │  │  └──────────────────────────┘  │  │
                    │  └────────────────────────────────┘  │
                    │                                       │
                    │  ┌────────────────────────────────┐  │
                    │  │  Private Subnets (2 AZs)       │  │
                    │  │                                │  │
                    │  │  ┌──────────────────────────┐  │  │
                    │  │  │   ECS Cluster (Fargate)  │  │  │
                    │  │  │                          │  │  │
                    │  │  │ ┌────────────────────┐  │  │  │
                    │  │  │ │  Task 1 (10.0.11)  │  │  │  │
                    │  │  │ │  • App Container   │  │  │  │
                    │  │  │ │  • CPU: 256        │  │  │  │
                    │  │  │ │  • Memory: 512MB   │  │  │  │
                    │  │  │ └────────────────────┘  │  │  │
                    │  │  │                          │  │  │
                    │  │  │ ┌────────────────────┐  │  │  │
                    │  │  │ │  Task 2 (10.0.12)  │  │  │  │
                    │  │  │ │  • App Container   │  │  │  │
                    │  │  │ │  • CPU: 256        │  │  │  │
                    │  │  │ │  • Memory: 512MB   │  │  │  │
                    │  │  │ └────────────────────┘  │  │  │
                    │  │  │                          │  │  │
                    │  │  │ Auto Scaling: 2-6 tasks │  │  │
                    │  │  │ • CPU Target: 70%       │  │  │
                    │  │  │ • Memory Target: 80%    │  │  │
                    │  │  └──────────────────────────┘  │  │
                    │  └────────────────────────────────┘  │
                    │                                       │
                    │  ┌────────────────────────────────┐  │
                    │  │   Database Layer               │  │
                    │  │  ┌──────────────────────────┐  │  │
                    │  │  │  RDS PostgreSQL (-) │  │
                    │  │  │                          │  │  │
                    │  │  │ Primary (AZ-1)           │  │  │
                    │  │  │ • Instance: db.t3.micro  │  │  │
                    │  │  │ • Storage: 20GB          │  │  │
                    │  │  │ • Backup: 7 dias         │  │  │
                    │  │  │                          │  │  │
                    │  │  │ Standby (AZ-2)           │  │  │
                    │  │  │ • Replicação automática  │  │  │
                    │  │  │ • Failover automático    │  │  │
                    │  │  └──────────────────────────┘  │  │
                    │  └────────────────────────────────┘  │
                    │                                       │
                    │  ┌────────────────────────────────┐  │
                    │  │   Logging & Monitoring         │  │
                    │  │  • CloudWatch Logs             │  │
                    │  │  • CloudWatch Metrics          │  │
                    │  │  • CloudWatch Alarms           │  │
                    │  └────────────────────────────────┘  │
                    └─────────────────────────────────────┘
                                      ↓
                    ┌─────────────────────────────────────┐
                    │     AWS Services Suportadores       │
                    │  • ECR (Container Registry)         │
                    │  • Secrets Manager                  │
                    │  • IAM (Access Control)             │
                    │  • CloudWatch (Monitoring)          │
                    │  • Auto Scaling                     │
                    └─────────────────────────────────────┘
```

## Fluxo de Deployment

```
Developer
    ↓
Git Push (main)
    ↓
GitHub Actions Triggered
    ├─ Build Docker Image
    ├─ Security Scan (Trivy)
    ├─ Tests
    ├─ Push to ECR
    └─ Update ECS Service
           ↓
    New Task Definition
           ↓
    ECS Rolling Deployment
           ├─ Start new tasks
           ├─ Health checks
           ├─ Drain connections
           └─ Stop old tasks
                ↓
        Application Live
```

## Componentes da Arquitetura

### 1. Camada de Apresentação
- **CloudFront**: Distribuição de conteúdo global
- **ALB**: Balanceamento de carga com health checks

### 2. Camada de Aplicação
- **ECS Fargate**: Orquestração de containers serverless
- **Auto Scaling**: Escala baseada em CPU/Memória
- **CloudWatch**: Logging e monitoramento

### 3. Camada de Dados
- **RDS PostgreSQL**: Banco de dados gerenciado
- **Multi-AZ**: Alta disponibilidade automática..
- **Secrets Manager**: Gerenciamento seguro de credenciais

### 4. Segurança
- **VPC**: Isolamento de rede
- **Security Groups**: Firewall entre camadas
- **IAM Roles**: Controle de acesso granular
- **Encriptação**: Em repouso e em trânsito

## Endpoints da API

```
GET  /              → Health check básico
GET  /health        → Status detalhado
GET  /ready         → Verifica conexão com banco
GET  /connect       → Conecta e retorna versão do PostgreSQL
POST /requests      → Salva requisição no banco
GET  /requests      → Lista requisições (limit: 10)
```

## Variáveis de Ambiente

### Produção (ECS)
- Armazenadas em **Secrets Manager**
- Injetadas via task definition
- Atualizadas sem rebuild

### Desenvolvimento (Docker Compose)
- Arquivo `.env.local`
- Variáveis no docker-compose.yml
- Facilita testes locais

## Boas Práticas Implementadas

✅ **Escalabilidade**
- Auto Scaling baseado em métricas
- Load Balancing entre zonas
- Stateless application design

✅ **Disponibilidade**
- Multi-AZ deployment
- Health checks automáticos
- Graceful shutdown

✅ **Segurança**
- VPC privada para aplicação
- Secrets Manager para credenciais
- Security Groups restritivos
- Scanning de imagens Docker

✅ **Observabilidade**
- CloudWatch Logs consolidados
- Métricas em tempo real
- Alarms para anomalias
- Distributed tracing ready

✅ **IaC (Infrastructure as Code)**
- Terraform para reproducibilidade
- Versionamento de estado
- Modularização clara
- Fácil destruição/recriação

✅ **CI/CD**
- GitHub Actions
- Testes automáticos
- Scan de segurança
- Deployment zero-downtime
