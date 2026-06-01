# ============================================================
# GitHub Actions OIDC — autenticação sem chaves IAM estáticas
# ============================================================

variable "github_repo" {
  description = "Repositório GitHub autorizado (formato: owner/repo)"
  type        = string
  default     = "cristianluiztic/KXC-TESTE"
}

# Identity Provider do GitHub no IAM
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # Thumbprints da CA raiz do GitHub (ambos ativos)
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}

# ============================================================
# Role de build — ECR apenas (todas as branches e PRs)
# ============================================================

resource "aws_iam_role" "github_build" {
  name = "${var.project_name}-github-build-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Qualquer contexto do repositório (branches, PRs, schedule)
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
        }
      }
    }]
  })

  tags = { Name = "${var.project_name}-github-build-role" }
}

resource "aws_iam_role_policy" "github_build_ecr" {
  name = "${var.project_name}-github-build-ecr"
  role = aws_iam_role.github_build.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # GetAuthorizationToken não aceita Resource específico
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}"
      }
    ]
  })
}

# ============================================================
# Role de deploy — ECR + ECS, restrito ao branch main
# ============================================================

resource "aws_iam_role" "github_deploy" {
  name = "${var.project_name}-github-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          # Apenas o branch main pode assumir esta role
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/main"
        }
      }
    }]
  })

  tags = { Name = "${var.project_name}-github-deploy-role" }
}

resource "aws_iam_role_policy" "github_deploy_ecr" {
  name = "${var.project_name}-github-deploy-ecr"
  role = aws_iam_role.github_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}"
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_deploy_ecs" {
  name = "${var.project_name}-github-deploy-ecs"
  role = aws_iam_role.github_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "ecs:DescribeTasks",
          "ecs:ListTasks"
        ]
        Resource = "*"
      },
      {
        # PassRole restrito às roles ECS do projeto — impede escalada de privilégios
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          aws_iam_role.ecs_task_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      }
    ]
  })
}

# ============================================================
# Outputs — copie os valores para os secrets do GitHub
# ============================================================

output "github_build_role_arn" {
  description = "ARN para o secret AWS_BUILD_ROLE_ARN no GitHub Actions"
  value       = aws_iam_role.github_build.arn
}

output "github_deploy_role_arn" {
  description = "ARN para o secret AWS_DEPLOY_ROLE_ARN no GitHub Actions"
  value       = aws_iam_role.github_deploy.arn
}
