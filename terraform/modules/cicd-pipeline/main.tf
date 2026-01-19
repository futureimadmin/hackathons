# CI/CD Pipeline Module for eCommerce AI Platform
# Creates AWS CodePipeline with GitHub integration

# S3 bucket for pipeline artifacts
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "${var.project_name}-pipeline-artifacts-${var.environment}"

  tags = merge(var.tags, {
    Name = "${var.project_name}-pipeline-artifacts-${var.environment}"
  })
}

resource "aws_s3_bucket_versioning" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

# CodeBuild IAM Role
resource "aws_iam_role" "codebuild" {
  name = "${var.project_name}-codebuild-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "codebuild" {
  name = "${var.project_name}-codebuild-policy-${var.environment}"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # For CloudWatch Logs (split into two statements for clarity)
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:ListTagsForResource",
          "logs:TagResource",
          "logs:UntagResource"
        ]
        Resource = [
          "arn:aws:logs:us-east-2:450133579764:log-group:/aws/lambda/${var.project_name}-*",
          "arn:aws:logs:us-east-2:450133579764:log-group:/aws/apigateway/${var.project_name}-*",
          "arn:aws:logs:us-east-2:450133579764:log-group:*:*"
        ]
      },
      # For CodeStar Connections
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection",
          "codestar-connections:GetConnection",
          "codestar-connections:CreateConnection",
          "codestar-connections:DeleteConnection",
          "codestar-connections:ListConnections",
          "codestar-connections:ListTagsForResource",
          "codestar-connections:TagResource",
          "codestar-connections:UntagResource"
        ]
        Resource = "arn:aws:codestar-connections:us-east-2:450133579764:connection/*"
      },
      # For Secrets Manager
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:TagResource",
          "secretsmanager:UntagResource"
        ]
        Resource = [
          "arn:aws:secretsmanager:us-east-2:450133579764:secret:${var.project_name}-*",
          "arn:aws:secretsmanager:us-east-2:450133579764:secret:futureim-ecommerce-ai-platform-github-token-*"
        ]
      },
      # For CloudWatch Metrics and Alarms
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarms",
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:ListTagsForResource",
          "cloudwatch:TagResource",
          "cloudwatch:UntagResource"
        ]
        Resource = [
          "arn:aws:cloudwatch:us-east-2:450133579764:alarm:${var.project_name}-*",
          "*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          "${aws_s3_bucket.pipeline_artifacts.arn}/*",
          "${aws_s3_bucket.pipeline_artifacts.arn}",
          "arn:aws:s3:::*",
          "arn:aws:s3:::*/*",
          "arn:aws:s3:::${var.frontend_bucket_name}/*",
          "arn:aws:s3:::${var.frontend_bucket_name}",
          "arn:aws:s3:::${var.project_name}-*/*",
          "arn:aws:s3:::${var.project_name}-*",
          "arn:aws:s3:::compliance-guardian-*/*",
          "arn:aws:s3:::compliance-guardian-*",
          "arn:aws:s3:::global-market-pulse-*/*",
          "arn:aws:s3:::global-market-pulse-*",
          "arn:aws:s3:::demand-insights-engine-*/*",
          "arn:aws:s3:::demand-insights-engine-*",
          "arn:aws:s3:::retail-copilot-*/*",
          "arn:aws:s3:::retail-copilot-*",
          "arn:aws:s3:::market-intelligence-hub-*/*",
          "arn:aws:s3:::market-intelligence-hub-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:*"
        ]
        Resource = "arn:aws:lambda:*:*:function:${var.project_name}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "vpc:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "apigateway:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:*"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.project_name}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "glue:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/${var.project_name}/${var.environment}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetProjects",
          "codebuild:CreateProject",
          "codebuild:UpdateProject",
          "codebuild:DeleteProject",
          "codebuild:StartBuild",
          "codebuild:StopBuild",
          "codebuild:ListBuilds",
          "codebuild:BatchGetBuilds"
        ]
        Resource = "arn:aws:codebuild:us-east-2:450133579764:project/${var.project_name}-*"
      }
    ]
  })
}

# CodePipeline IAM Role
resource "aws_iam_role" "codepipeline" {
  name = "${var.project_name}-codepipeline-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "${var.project_name}-codepipeline-policy-${var.environment}"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.pipeline_artifacts.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.pipeline_artifacts.arn
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = "arn:aws:codebuild:*:*:project/${var.project_name}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = aws_codestarconnections_connection.github.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# GitHub Connection
resource "aws_codestarconnections_connection" "github" {
  name          = "futureim-github-${var.environment}"
  provider_type = "GitHub"

  tags = var.tags
}

# Store GitHub token in Secrets Manager
resource "aws_secretsmanager_secret" "github_token" {
  name = "${var.project_name}-github-token-${var.environment}"
  kms_key_id = var.kms_key_arn

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "github_token" {
  secret_id     = aws_secretsmanager_secret.github_token.id
  secret_string = var.github_token != "" ? var.github_token : "placeholder-token-update-manually"

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# CodeBuild Project - Infrastructure
resource "aws_codebuild_project" "infrastructure" {
  name          = "${var.project_name}-infrastructure-${var.environment}"
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }

    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspecs/infrastructure-buildspec.yml"
  }

  tags = var.tags
}

# CodeBuild Project - Java Lambda (Auth Service)
resource "aws_codebuild_project" "java_lambda" {
  name          = "${var.project_name}-java-lambda-${var.environment}"
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }

    environment_variable {
      name  = "LAMBDA_FUNCTION_NAME"
      value = "${var.project_name}-auth-${var.environment}"
    }

    environment_variable {
      name  = "LAMBDA_ROLE_ARN"
      value = var.lambda_execution_role_arn
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspecs/java-lambda-buildspec.yml"
  }

  tags = var.tags
}

# CodeBuild Project - Python Lambdas
resource "aws_codebuild_project" "python_lambdas" {
  name          = "${var.project_name}-python-lambdas-${var.environment}"
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }

    environment_variable {
      name  = "PROJECT_NAME"
      value = var.project_name
    }

    environment_variable {
      name  = "LAMBDA_ROLE_ARN"
      value = var.lambda_execution_role_arn
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspecs/python-lambdas-buildspec.yml"
  }

  tags = var.tags
}

# CodeBuild Project - Frontend
resource "aws_codebuild_project" "frontend" {
  name          = "${var.project_name}-frontend-${var.environment}"
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }

    environment_variable {
      name  = "API_GATEWAY_URL"
      value = var.api_gateway_url
    }

    environment_variable {
      name  = "FRONTEND_BUCKET"
      value = var.frontend_bucket_name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspecs/frontend-buildspec.yml"
  }

  tags = var.tags
}

# CodePipeline
resource "aws_codepipeline" "main" {
  name          = "${var.project_name}-pipeline-${var.environment}"
  role_arn      = aws_iam_role.codepipeline.arn
  pipeline_type = "V2"

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"

    encryption_key {
      id   = var.kms_key_arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn        = aws_codestarconnections_connection.github.arn
        FullRepositoryId     = var.github_repo
        BranchName           = var.github_branch
        DetectChanges        = "true"
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Infrastructure"

    action {
      name             = "DeployInfrastructure"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["infrastructure_output"]

      configuration = {
        ProjectName = aws_codebuild_project.infrastructure.name
      }
    }
  }

  stage {
    name = "BuildLambdas"

    action {
      name             = "BuildJavaLambda"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["java_lambda_output"]
      run_order        = 1

      configuration = {
        ProjectName = aws_codebuild_project.java_lambda.name
      }
    }

    action {
      name             = "BuildPythonLambdas"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["python_lambdas_output"]
      run_order        = 1

      configuration = {
        ProjectName = aws_codebuild_project.python_lambdas.name
      }
    }
  }

  stage {
    name = "BuildFrontend"

    action {
      name             = "BuildAndDeployFrontend"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output", "infrastructure_output"]
      output_artifacts = ["frontend_output"]

      configuration = {
        ProjectName   = aws_codebuild_project.frontend.name
        PrimarySource = "source_output"
      }
    }
  }

  tags = var.tags
}
