# Simple API

API simples em Express.js com integração ao PostgreSQL, containerizada e pronta para deployment em nuvem.

## 🚀 Quick Start (Desenvolvimento Local)

### Pré-requisitos
- Docker e Docker Compose
- Node.js 18+ (opcional para desenvolvimento local)

### Iniciar Aplicação

```bash
# Com Docker Compose
docker-compose up

# Sem Docker Compose (requer PostgreSQL local)
npm install
npm start
```

A aplicação estará disponível em `http://localhost:3000`

## 📋 Endpoints

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/` | Health check básico |
| GET | `/health` | Status detalhado |
| GET | `/ready` | Verifica conexão com banco |
| GET | `/connect` | Testa conexão e retorna versão PostgreSQL |
| POST | `/requests` | Salva requisição no banco |
| GET | `/requests` | Lista requisições |

## 🏗️ Arquitetura

```
┌─────────────────────────────────────┐
│      CloudFront (Opcional)          │
├─────────────────────────────────────┤
│   Application Load Balancer         │
├─────────────────────────────────────┤
│   ECS Fargate (2-6 tasks)           │
│   └─ Auto Scaling (CPU/Memory)      │
├─────────────────────────────────────┤
│   RDS PostgreSQL (Multi-AZ)         │
└─────────────────────────────────────┘
```

Veja [ARCHITECTURE.md](ARCHITECTURE.md) para diagrama completo.

## 📦 Docker

### Build

```bash
docker build -t simple-api .
```

### Run

```bash
docker run -p 3000:3000 \
  -e DB_HOST=postgres \
  -e DB_PORT=5432 \
  -e DB_USER=postgres \
  -e DB_PASSWORD=password \
  -e DB_DATABASE=simpleapi \
  simple-api
```

## ☁️ Deployment na AWS

### Estrutura Terraform

```
terraform/
├── main.tf                    # Infraestrutura principal (VPC, ALB, ECS)
├── rds-autoscaling.tf        # RDS PostgreSQL e Auto Scaling
├── variables.tf               # Variáveis
├── rds-variables.tf          # Variáveis RDS
├── outputs.tf                # Outputs
├── terraform.tfvars          # Valores padrão
└── README.md                 # Documentação Terraform
```

### Quick Deploy

1. **Preparar ECR**
   ```bash
   export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   export AWS_REGION=us-east-1
   
   aws ecr create-repository --repository-name simple-api
   ```

2. **Build e Push**
   ```bash
   aws ecr get-login-password | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
   docker build -t simple-api .
   docker tag simple-api $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/simple-api:latest
   docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/simple-api:latest
   ```

3. **Deploy com Terraform**
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

Veja [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) para instruções detalhadas.

## 🔄 CI/CD Pipeline

A aplicação possui GitHub Actions configurado para:

- ✅ Build automático de Docker images
- ✅ Security scan com Trivy
- ✅ Push para ECR
- ✅ Deployment automático para ECS
- ✅ Verificação de saúde

Workflows:
- `.github/workflows/deploy.yml` - Build, test e deploy
- `.github/workflows/security.yml` - Security scanning

## 💾 Banco de Dados

### Local (Docker Compose)
- **Engine**: PostgreSQL 15
- **User**: postgres
- **Password**: postgres
- **Database**: simpleapi
- **Port**: 5432

### Produção (AWS RDS)
- **Multi-AZ**: Replicação automática entre zonas
- **Backup**: 7 dias de retenção
- **Encriptação**: EBS com criptografia AES-256
- **Monitoring**: CloudWatch Alarms

Tabelas:
```sql
CREATE TABLE requests (
    id SERIAL PRIMARY KEY,
    path VARCHAR(255),
    method VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 📊 Monitoramento

### CloudWatch
- **Logs**: `/ecs/simple-api` (7 dias de retenção)
- **Métricas**: CPU, Memória, Requisições
- **Alarms**: CPU >80%, Memória >80%, Storage <2GB

### Health Checks
```bash
# Verificar saúde
curl http://localhost:3000/health
# { "status": "healthy", "timestamp": "2026-05-30T..." }

# Verificar prontidão
curl http://localhost:3000/ready
# { "ready": true }
```

## 🔐 Segurança

- ✅ Credenciais em **Secrets Manager** (não em código)
- ✅ VPC privada para aplicação
- ✅ Security Groups restritivos
- ✅ Scanning de imagens Docker
- ✅ IAM roles com permissões mínimas
- ✅ Encriptação em repouso e trânsito

## 📈 Auto Scaling

A aplicação escala automaticamente:
- **Mínimo**: 2 tasks
- **Máximo**: 6 tasks
- **CPU Target**: 70%
- **Memory Target**: 80%

## 🛠️ Variáveis de Ambiente

```bash
# Aplicação
API_PORT=3000
NODE_ENV=development

# Banco de Dados
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_DATABASE=simpleapi
```

Veja `.env.example` para a lista completa.

## 📚 Documentação

- [ARCHITECTURE.md](ARCHITECTURE.md) - Arquitetura completa
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Guia de deployment
- [CLOUD_BEST_PRACTICES.md](CLOUD_BEST_PRACTICES.md) - Boas práticas na nuvem
- [terraform/README.md](terraform/README.md) - Documentação Terraform

## 🧪 Testes

```bash
# Instalar dependências
npm install

# Testes (quando configurados)
npm test
```

## 📝 Scripts

```bash
# Desenvolvimento
npm run dev

# Produção
npm start

# Deployment
bash scripts/deploy.sh
```

## 📄 Licença

ISC

## 👨‍💻 Autor

Desenvolvido como exemplo de aplicação moderna containerizada e pronta para produção.

---

## Roadmap

- [ ] Adicionar HTTPS/TLS
- [ ] Implementar caching com Redis
- [ ] Adicionar testes unitários
- [ ] Setup de observabilidade com Prometheus + Grafana
- [ ] Implementar API Gateway
- [ ] Adicionar rate limiting
- [ ] Documentação OpenAPI/Swagger
| --- | --- | --- |
/ | GET | Retorna uma mensagem estática.
/connect | GET | Realiza a conexão com o banco e retorna a versão da engine.


## Variáveis de Ambiente
| Nome | Description  | Padrão |
| --- |  --- |  --- |
API_PORT | Port da API Node | 3000
DB_DATABASE | Database do banco de dados | 
DB_HOST | Endereço do banco de dados | 
DB_PORT | Port do banco de dados | 5432
DB_USER | Usuário do banco de dados | 
DB_PASSWORD | Senha do banco de dados | 