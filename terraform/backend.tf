# ============================================================
# Terraform Remote Backend — S3 + DynamoDB
# ============================================================
# ATENÇÃO: O bucket S3 e a tabela DynamoDB devem existir ANTES
# de rodar `terraform init`. Use o script scripts/bootstrap-backend.sh
# para criá-los uma única vez.
#
# Após criar os recursos de bootstrap, rode:
#   terraform init -backend-config="bucket=SEU_BUCKET" \
#                  -backend-config="dynamodb_table=SEU_TABLE"
# ============================================================

terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "simple-api-tfstate-468142523818"
    key            = "simple-api/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "simple-api-tf-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
