# Guia de Setup e Deployment

## 1. Setup Local (Desenvolvimento)

### Pré-requisitos
- Docker e Docker Compose instalados
- Node.js 18+
- PostgreSQL CLI (opcional)

### Executar Localmente

```bash
# Instalar dependências
npm install

# Iniciar com Docker Compose
docker-compose up

# Acessar a API
curl http://localhost:3000
curl http://localhost:3000/connect
```

### Estrutura de Banco de Dados

O PostgreSQL será iniciado automaticamente com:
- Username: postgres
- Password: postgres
- Database: simpleapi
- Port: 5432

Tabelas iniciais são criadas via `scripts/init.sql`

## 2. Setup na AWS

### 1. Preparação Inicial

```bash
# Configurar variáveis
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export PROJECT_NAME=simple-api
```

### 2. Criar ECR Repository

```bash
# Criar repositório no ECR
aws ecr create-repository \
  --repository-name $PROJECT_NAME \
  --region $AWS_REGION

# Habilitarimagem scanning
aws ecr put-image-scanning-configuration \
  --repository-name $PROJECT_NAME \
  --image-scanning-configuration scanOnPush=true \
  --region $AWS_REGION
```

### 3. Build e Push da Imagem Docker

```bash
# Fazer login no ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build
docker build -t $PROJECT_NAME:latest .

# Tag
docker tag $PROJECT_NAME:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME:latest

# Push
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME:latest
```

### 4. Deploy com Terraform

```bash
cd terraform

# Atualizar terraform.tfvars
cat >> terraform.tfvars << EOF
container_image_uri = "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME"
container_image_tag = "latest"
EOF

# Validar configuração
terraform validate

# Planejar deployment
terraform plan -out=tfplan

# Aplicar
terraform apply tfplan

# Obter outputs
terraform output
```

### 5. Configurar GitHub Actions

#### Secrets necessários no GitHub
```
AWS_ACCESS_KEY_ID          - Chave de acesso AWS
AWS_SECRET_ACCESS_KEY      - Chave secreta AWS
SNYK_TOKEN                 - Token Snyk (opcional)
```

#### Como adicionar secrets:
1. Ir para: Settings → Secrets and variables → Actions
2. Click em "New repository secret"
3. Adicionar cada secret com seu valor

### 6. Após Deploy

```bash
# Obter DNS do Load Balancer
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'simple-api')].DNSName" \
  --output text)

# Testar aplicação
curl http://$ALB_DNS/
curl http://$ALB_DNS/health
curl http://$ALB_DNS/ready
curl http://$ALB_DNS/connect

# Listar requisições
curl http://$ALB_DNS/requests
```

## 3. Pipeline CI/CD

### GitHub Actions Workflow

1. **Deploy Workflow** (`.github/workflows/deploy.yml`)
   - Acionado em push para `main`
   - Build Docker image
   - Push para ECR
   - Update ECS Service
   - Validação com Trivy

2. **Security Workflow** (`.github/workflows/security.yml`)
   - Acionado em push e pull requests
   - Scan Trivy (vulnerabilidades)
   - Scan Snyk (dependências)

### Processo de Deployment

```
git push main
  ↓
GitHub Actions Triggered
  ├─ Build Docker Image
  ├─ Scan com Trivy
  ├─ Push para ECR
  ├─ Register Task Definition
  ├─ Update ECS Service
  └─ Wait for Stability
```

## 4. Monitoramento

### CloudWatch Logs

```bash
# Ver logs em tempo real
aws logs tail /ecs/simple-api --follow

# Ver logs de um período específico
aws logs filter-log-events \
  --log-group-name /ecs/simple-api \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --region $AWS_REGION
```

### CloudWatch Metrics

```bash
# Ver métrica de CPU
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=simple-api-service Name=ClusterName,Value=simple-api-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region $AWS_REGION
```

## 5. Escala e Performance

### Auto Scaling

A aplicação escala automaticamente baseado em:
- CPU > 70%: Adiciona tasks
- Memória > 80%: Adiciona tasks
- Máximo: 6 tasks

### Ajustar Limites

```bash
cd terraform

# Editar rds-terraform.tfvars
autoscaling_min_capacity = 2
autoscaling_max_capacity = 10
autoscaling_target_cpu = 60
autoscaling_target_memory = 75

terraform plan
terraform apply
```

## 6. Destruição de Recursos

```bash
cd terraform

# Verificar o que será destruído
terraform plan -destroy

# Destruir (criará snapshot final do RDS)
terraform destroy
```

## 7. Troubleshooting

### Tarefa não inicia

```bash
# Ver logs da task
aws ecs describe-tasks \
  --cluster simple-api-cluster \
  --tasks <task-arn> \
  --query 'tasks[0].{LastStatus: lastStatus, StoppedReason: stoppedReason}'
```

### Verificar conexão com banco

```bash
curl http://$ALB_DNS/ready
# Retorna { "ready": true } se conectado
```

### Ver status do serviço

```bash
aws ecs describe-services \
  --cluster simple-api-cluster \
  --services simple-api-service \
  --query 'services[0].{Status: status, RunningCount: runningCount, DesiredCount: desiredCount}'
```

## 8. Rotina de Manutenção

### Backup Manual do RDS

```bash
aws rds create-db-snapshot \
  --db-instance-identifier simple-api-db \
  --db-snapshot-identifier simple-api-backup-$(date +%Y%m%d-%H%M%S)
```

### Limpeza de Imagens ECR Antigas

```bash
# Listar imagens
aws ecr describe-images --repository-name $PROJECT_NAME

# Remove imagens antigas (lifecycle policy já configurada)
# As políticas estão definidas em terraform/rds-autoscaling.tf
```

### Atualizar Dependências

```bash
npm update
docker build -t $PROJECT_NAME:$(date +%s) .
# Push e atualizar ECS
```
