#!/bin/bash

# Deploy script para Simple API
# Este script automatiza o deployment da aplicação na AWS

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variáveis
AWS_REGION=${AWS_REGION:-us-east-1}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-}
PROJECT_NAME="simple-api"
ECR_REPOSITORY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME"
IMAGE_TAG=${1:-latest}

# Funções
print_header() {
    echo -e "\n${GREEN}=== $1 ===${NC}\n"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Verificar pré-requisitos
check_prerequisites() {
    print_header "Verificando Pré-requisitos"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker não está instalado"
        exit 1
    fi
    print_success "Docker encontrado"
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI não está instalado"
        exit 1
    fi
    print_success "AWS CLI encontrado"
    
    if ! command -v terraform &> /dev/null; then
        print_warning "Terraform não está instalado (necessário para IaC)"
    else
        print_success "Terraform encontrado"
    fi
    
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        print_error "Variável AWS_ACCOUNT_ID não está definida"
        exit 1
    fi
    print_success "AWS_ACCOUNT_ID configurado"
}

# Build da imagem Docker
build_docker_image() {
    print_header "Building Docker Image"
    
    docker build -t $PROJECT_NAME:$IMAGE_TAG .
    print_success "Docker image built: $PROJECT_NAME:$IMAGE_TAG"
}

# Login no ECR
login_ecr() {
    print_header "Fazendo login no ECR"
    
    aws ecr get-login-password --region $AWS_REGION | \
        docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
    print_success "Login no ECR realizado"
}

# Tag e push para ECR
push_to_ecr() {
    print_header "Push para ECR"
    
    docker tag $PROJECT_NAME:$IMAGE_TAG $ECR_REPOSITORY:$IMAGE_TAG
    docker push $ECR_REPOSITORY:$IMAGE_TAG
    print_success "Imagem enviada para ECR: $ECR_REPOSITORY:$IMAGE_TAG"
    
    # Tag como latest também
    docker tag $PROJECT_NAME:$IMAGE_TAG $ECR_REPOSITORY:latest
    docker push $ECR_REPOSITORY:latest
    print_success "Latest tag atualizado"
}

# Deploy com Terraform
deploy_infrastructure() {
    print_header "Deploy da Infraestrutura com Terraform"
    
    cd terraform
    
    print_warning "Atualizando terraform.tfvars com a nova imagem..."
    echo "container_image_uri = \"$ECR_REPOSITORY\"" >> terraform.tfvars.tmp
    echo "container_image_tag = \"$IMAGE_TAG\"" >> terraform.tfvars.tmp
    
    terraform plan -out=tfplan
    print_success "Terraform plan criado"
    
    read -p "Deseja aplicar as mudanças? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform apply tfplan
        print_success "Infraestrutura atualizada"
    else
        print_warning "Deploy cancelado"
    fi
    
    cd ..
}

# Atualizar ECS Service
update_ecs_service() {
    print_header "Atualizando ECS Service"
    
    # Obter task definition
    TASK_DEF=$(aws ecs describe-task-definition \
        --task-definition $PROJECT_NAME \
        --region $AWS_REGION \
        --query 'taskDefinition' \
        --output json)
    
    # Atualizar imagem
    NEW_TASK_DEF=$(echo $TASK_DEF | jq \
        --arg IMAGE "$ECR_REPOSITORY:$IMAGE_TAG" \
        '.containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)')
    
    # Registrar nova task definition
    TASK_DEF_ARN=$(echo $NEW_TASK_DEF | aws ecs register-task-definition \
        --region $AWS_REGION \
        --cli-input-json file:///dev/stdin \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)
    
    print_success "Nova task definition registrada: $TASK_DEF_ARN"
    
    # Atualizar serviço
    aws ecs update-service \
        --cluster ${PROJECT_NAME}-cluster \
        --service ${PROJECT_NAME}-service \
        --task-definition $TASK_DEF_ARN \
        --region $AWS_REGION
    
    print_success "ECS Service atualizado"
}

# Verificar deployment status
check_deployment_status() {
    print_header "Verificando Status do Deployment"
    
    echo "Aguardando estabilização do serviço..."
    aws ecs wait services-stable \
        --cluster ${PROJECT_NAME}-cluster \
        --services ${PROJECT_NAME}-service \
        --region $AWS_REGION
    
    print_success "Serviço estabilizado"
    
    # Obter informações do ALB
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --region $AWS_REGION \
        --query "LoadBalancers[?contains(LoadBalancerName, 'simple-api')].DNSName" \
        --output text)
    
    echo ""
    echo -e "${GREEN}=== Deployment Concluído ===${NC}"
    echo "Aplicação disponível em: http://$ALB_DNS"
    echo ""
}

# Menu principal
show_menu() {
    echo ""
    echo "=== Simple API Deployment ==="
    echo "1. Build Docker Image"
    echo "2. Push para ECR"
    echo "3. Deploy Infraestrutura (Terraform)"
    echo "4. Atualizar ECS Service"
    echo "5. Build + Push + Update ECS (completo)"
    echo "6. Verificar Status"
    echo "0. Sair"
    echo ""
}

# Main
main() {
    check_prerequisites
    
    if [ -z "$1" ]; then
        while true; do
            show_menu
            read -p "Escolha uma opção: " choice
            
            case $choice in
                1) build_docker_image ;;
                2) login_ecr && push_to_ecr ;;
                3) deploy_infrastructure ;;
                4) update_ecs_service ;;
                5)
                    build_docker_image
                    login_ecr
                    push_to_ecr
                    update_ecs_service
                    check_deployment_status
                    ;;
                6) check_deployment_status ;;
                0) exit 0 ;;
                *) echo "Opção inválida" ;;
            esac
        done
    else
        case "$1" in
            build) build_docker_image ;;
            push) login_ecr && push_to_ecr ;;
            terraform) deploy_infrastructure ;;
            update) update_ecs_service ;;
            full)
                build_docker_image
                login_ecr
                push_to_ecr
                update_ecs_service
                check_deployment_status
                ;;
            status) check_deployment_status ;;
            *) echo "Comando desconhecido: $1" ;;
        esac
    fi
}

main "$@"
