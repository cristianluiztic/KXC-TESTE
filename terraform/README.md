# Infraestrutura Terraform - Simple API

## Descrição

Infraestrutura AWS para deploy da aplicação Simple API em container usando ECS Fargate.

## Arquitetura

```
VPC (10.0.0.0/16)
├── Public Subnets (Availability Zone 1 e 2)
│   ├── Internet Gateway
│   └── NAT Gateway
├── Private Subnets (Availability Zone 1 e 2)
│   └── ECS Tasks (Fargate)
├── Application Load Balancer
├── ECS Cluster
└── Security Groups
```

## Pré-requisitos

1. **Terraform** >= 1.0
2. **AWS CLI** configurado com credenciais válidas
3. **Imagem Docker** registrada no ECR (Elastic Container Registry)

## Configuração Inicial

### 1. Preparar Imagem Docker no ECR

```bash
# Fazer login no ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin seu-account-id.dkr.ecr.us-east-1.amazonaws.com

# Tag da imagem
docker tag simple-api seu-account-id.dkr.ecr.us-east-1.amazonaws.com/simple-api:latest

# Push para ECR
docker push seu-account-id.dkr.ecr.us-east-1.amazonaws.com/simple-api:latest
```

### 2. Atualizar terraform.tfvars

Edite `terraform.tfvars` e substitua:
- `seu-account-id` pelo seu AWS Account ID
- Ajuste as variáveis conforme necessário

### 3. Deploy

```bash
# Inicializar Terraform
terraform init

# Planejar deployment
terraform plan

# Aplicar configuração
terraform apply
```

## Variáveis

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `aws_region` | Região AWS | us-east-1 |
| `project_name` | Nome do projeto | simple-api |
| `container_cpu` | CPU do container | 256 |
| `container_memory` | Memória do container | 512 |
| `desired_count` | Quantidade de tasks | 2 |
| `container_image_uri` | URI da imagem no ECR | - |
| `container_image_tag` | Tag da imagem | latest |

## Outputs

Após o deploy, você receberá:
- **alb_dns_name**: DNS do Load Balancer (para acessar a aplicação)
- **vpc_id**: ID da VPC criada
- **ecs_cluster_name**: Nome do cluster ECS
- **cloudwatch_log_group**: Grupo de logs CloudWatch

## Acessar a Aplicação

```bash
curl http://<alb_dns_name>/
curl http://<alb_dns_name>/connect
```

## Monitorar Logs

```bash
aws logs tail /ecs/simple-api --follow
```

## Destruir Infraestrutura

```bash
terraform destroy
```

## Estrutura de Custos

- **ALB**: ~$16-20/mês
- **ECS Fargate**: Depende do CPU/Memory e horas de execução
- **NAT Gateway**: ~$32/mês + dados
- **CloudWatch Logs**: ~$0.50 por GB

## Melhorias Futuras

- [ ] Adicionar HTTPS/TLS
- [ ] Implementar Auto Scaling
- [ ] Adicionar banco de dados RDS
- [ ] Configurar CI/CD com CodePipeline
- [ ] Implementar monitoring com CloudWatch Alarms
