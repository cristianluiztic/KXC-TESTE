# Boas Práticas na Nuvem

## Escalabilidade

### Auto Scaling
A infraestrutura foi configurada com Auto Scaling automático baseado em:
- **CPU**: Escala quando atinge 70% de utilização
- **Memória**: Escala quando atinge 80% de utilização
- **Mínimo**: 2 tasks (alta disponibilidade)
- **Máximo**: 6 tasks (controle de custo)

### Banco de Dados
- **RDS Multi-AZ**: Replica automática entre zonas de disponibilidade
- **Backup**: Retenção de 7 dias com snapshots automáticos
- **Armazenamento**: EBS com encriptação habilitada
- **Índices**: Criados em colunas frequentemente consultadas

### Load Balancing
- **ALB**: Distribui tráfego entre múltiplas AZs
- **Health Checks**: Verifica saúde das tasks a cada 30 segundos
- **Connection Draining**: Encerra gracefully conexões ao remover tasks

## Disponibilidade

### Multi-AZ (Múltiplas Zonas de Disponibilidade)
- **Subnets**: 2 públicas + 2 privadas em AZs diferentes
- **NAT Gateway**: Uma em cada AZ pública
- **RDS**: Multi-AZ ativo-passivo com failover automático
- **ECS**: Tasks distribuídas entre AZs

### Health Checks
```
GET /health - Simples verificação de status
GET /ready  - Verifica conexão com banco de dados
```

Endpoints integrados:
- **ALB**: Verifica GET / a cada 30 segundos
- **ECS**: Restart automático se task falhar
- **RDS**: Failover automático em caso de indisponibilidade

## Segurança

### Network Isolation
- **VPC Privada**: Tasks rodam em subnets privadas
- **Security Groups**: Tráfego restrito a portas específicas
- **NAT Gateway**: Únicoponto de saída para internet
- **VPC Endpoints**: Acesso a serviços AWS sem internet

### Dados Sensíveis
- **Secrets Manager**: Credenciais do banco armazenadas com encriptação
- **IAM Roles**: Permissões mínimas por task
- **Encriptação**: EBS, RDS e secrets em repouso

### Imagens Docker
- **Trivy Scan**: Analisa vulnerabilidades em cada push
- **ECR Lifecycle**: Remove imagens antigas automaticamente
- **Image Scanning**: Verifica automaticamente ao fazer push

## Camadas de Aplicação

```
┌─────────────────────────────────────────┐
│       CloudFront (CDN)                   │
├─────────────────────────────────────────┤
│   Application Load Balancer (ALB)        │
├─────────────────────────────────────────┤
│   ECS Cluster (Fargate)                  │
│   ├─ Task 1 (10.0.11.0/24)              │
│   ├─ Task 2 (10.0.12.0/24)              │
│   └─ Auto Scaling (2-6 tasks)            │
├─────────────────────────────────────────┤
│   RDS PostgreSQL (Multi-AZ)              │
│   ├─ Primary (us-east-1a)               │
│   └─ Standby (us-east-1b)               │
└─────────────────────────────────────────┘
```

## Monitoramento

### CloudWatch
- **Logs**: /ecs/simple-api com retenção de 7 dias
- **Métricas**: CPU, Memória, Requisições
- **Alarms**: Alertas para condições anormais

### Métricas Monitoradas
- CPU do ECS (alerta em >80%)
- CPU do RDS (alerta em >80%)
- Armazenamento RDS (alerta em <2GB)
- Hosts indisponíveis no ALB
- Latência das requisições

## Custo Otimização

### Fargate Spot
- Configurado para usar Fargate Spot quando possível
- Economiza até 70% em custos de computação
- Ideal para workloads que tolerem interrupções

### RDS t3.micro
- Instância de baixo custo com burstable performance
- Adequada para aplicações pequenas-médias
- Escale para instance classes maiores conforme necessário

### Armazenamento
- CloudWatch Logs: 7 dias de retenção
- RDS Backups: 7 dias com snapshots automáticos
- ECR: Retenção de 10 últimas imagens com tag

## Infraestrutura como Código

### Terraform
- **Versionamento**: Histórico completo de mudanças
- **Reprodutibilidade**: Ambiente consistente sempre
- **Modularização**: Fácil de estender e customizar
- **Destruição Segura**: Snapshots de banco antes de deletar

### Estado Remoto (Recomendado)
```hcl
terraform {
  backend "s3" {
    bucket         = "seu-bucket"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

## Manutenção

### Atualizações Seguras
1. Update de imagem Docker
2. GitHub Actions faz build e push
3. Nova task definition criada
4. ECS atualiza serviço gradualmente
5. ALB remove tasks antigas gracefully

### Rollback Rápido
```bash
# Ver versões anteriores
aws ecs describe-task-definition --task-definition simple-api --query 'taskDefinition.revision'

# Reverter para revisão anterior
aws ecs update-service --cluster simple-api-cluster \
  --service simple-api-service \
  --task-definition simple-api:1
```

## Checklist de Produção

- [ ] Secrets armazenados no Secrets Manager
- [ ] RDS Multi-AZ habilitado
- [ ] Backups automáticos configurados
- [ ] CloudWatch Alarms criados
- [ ] CloudFront habilitado para reduzir latência
- [ ] GitHub Actions secrets configurados
- [ ] Logs retidos por período apropriado
- [ ] Testes de failover executados
- [ ] Plano de disaster recovery documentado
- [ ] Monitoramento e alertas em place
