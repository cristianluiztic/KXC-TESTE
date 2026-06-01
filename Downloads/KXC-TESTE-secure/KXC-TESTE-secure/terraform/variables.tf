# ============================================================
# Variáveis — KXC Simple API
# ============================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto (usado como prefixo em todos os recursos)"
  type        = string
  default     = "simple-api"
}

# --- Rede ---

variable "vpc_cidr" {
  description = "CIDR block para VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  description = "CIDR block para public subnet 1"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR block para public subnet 2"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_1_cidr" {
  description = "CIDR block para private subnet 1"
  type        = string
  default     = "10.0.11.0/24"
}

variable "private_subnet_2_cidr" {
  description = "CIDR block para private subnet 2"
  type        = string
  default     = "10.0.12.0/24"
}

# --- Container ---

variable "container_image_uri" {
  description = "URI da imagem Docker no ECR (ex: 123456789012.dkr.ecr.us-east-1.amazonaws.com/simple-api)"
  type        = string
}

variable "container_image_tag" {
  description = "Tag da imagem Docker (usar SHA do commit, não 'latest')"
  type        = string
  default     = "latest"
}

variable "container_cpu" {
  description = "CPU para container (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "256"
}

variable "container_memory" {
  description = "Memória para container em MB"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Quantidade desejada de tasks ECS"
  type        = number
  default     = 2
}

# --- Segurança / ALB ---

variable "enable_deletion_protection" {
  description = "Ativa proteção contra deleção do ALB (recomendado true em produção)"
  type        = bool
  default     = false
}

# --- TLS / Domínio ---

variable "domain_name" {
  description = "Domínio principal da aplicação (ex: api.exemplo.com)"
  type        = string
}

variable "route53_zone_id" {
  description = "ID da hosted zone no Route53 para validação do certificado ACM"
  type        = string
}

# --- Observabilidade ---

variable "log_retention_days" {
  description = "Retenção dos logs no CloudWatch em dias"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Valor deve ser um dos aceitos pelo CloudWatch Logs."
  }
}

variable "alert_email" {
  description = "E-mail para receber alertas CloudWatch via SNS"
  type        = string
}

# --- RDS ---

variable "db_engine_version" {
  description = "Versão do PostgreSQL"
  type        = string
  default     = "15"
}

variable "db_instance_class" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Armazenamento inicial do RDS em GB"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
  default     = "simpleapi"
}

variable "db_username" {
  description = "Usuário master do RDS"
  type        = string
  default     = "postgres"
}

variable "db_skip_final_snapshot" {
  description = "Pula snapshot final ao destruir o RDS (false em produção)"
  type        = bool
  default     = false
}

variable "db_multi_az" {
  description = "Ativa Multi-AZ no RDS"
  type        = bool
  default     = true
}

variable "db_backup_retention" {
  description = "Dias de retenção de backups automáticos do RDS"
  type        = number
  default     = 7
}

# --- Auto Scaling ---

variable "autoscaling_min_capacity" {
  description = "Mínimo de tasks ECS"
  type        = number
  default     = 2
}

variable "autoscaling_max_capacity" {
  description = "Máximo de tasks ECS"
  type        = number
  default     = 6
}

variable "autoscaling_target_cpu" {
  description = "Alvo de utilização de CPU (%) para auto scaling"
  type        = number
  default     = 70
}

variable "autoscaling_target_memory" {
  description = "Alvo de utilização de memória (%) para auto scaling"
  type        = number
  default     = 80
}

# --- CloudFront ---

variable "enable_cloudfront" {
  description = "Ativa CloudFront Distribution na frente do ALB"
  type        = bool
  default     = true
}
