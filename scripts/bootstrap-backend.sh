#!/bin/bash
# ============================================================
# Bootstrap do Terraform Remote Backend
# Executar UMA ÚNICA VEZ antes do primeiro terraform init
# ============================================================

set -euo pipefail

AWS_REGION=${AWS_REGION:-us-east-1}
PROJECT_NAME=${PROJECT_NAME:-simple-api}
BUCKET_NAME="${PROJECT_NAME}-tfstate-$(aws sts get-caller-identity --query Account --output text)"
TABLE_NAME="${PROJECT_NAME}-tf-lock"

echo "==> Criando bucket S3 para estado Terraform: $BUCKET_NAME"

aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$AWS_REGION" \
  $([ "$AWS_REGION" != "us-east-1" ] && echo "--create-bucket-configuration LocationConstraint=$AWS_REGION" || echo "")

# Versioning obrigatório — permite rollback de estados corrompidos
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

# Criptografia SSE-S3 (ou substituir por SSE-KMS para maior controle)
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"},
      "BucketKeyEnabled": true
    }]
  }'

# Bloquear acesso público — estado não deve ser público jamais
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "==> Bucket criado com versioning + criptografia + bloqueio público"

echo "==> Criando tabela DynamoDB para lock: $TABLE_NAME"

aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$AWS_REGION"

echo ""
echo "==> Bootstrap concluído!"
echo ""
echo "Agora atualize terraform/backend.tf com:"
echo "  bucket         = \"$BUCKET_NAME\""
echo "  dynamodb_table = \"$TABLE_NAME\""
echo ""
echo "E inicialize: terraform init"
