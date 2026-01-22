# CI/CD Pipeline Module for eCommerce AI Platform
# Creates AWS CodePipeline with GitHub integration

# S3 bucket for pipeline artifacts
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "${var.project_name}-pipeline-artifacts-${var.environment}"

  # Prevent accidental deletion of bucket with build artifacts
  lifecycle {
    prevent_destroy = true
  }

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

# Attach AWS managed AdministratorAccess policy for demo project
resource "aws_iam_role_policy_attachment" "codebuild_admin" {
  role       = aws_iam_role.codebuild.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
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

# Attach AWS managed AdministratorAccess policy for demo project
resource "aws_iam_role_policy_attachment" "codepipeline_admin" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}



# GitHub Connection for automatic pipeline triggering
resource "aws_codestarconnections_connection" "github" {
  name          = "github-hackathons"
  provider_type = "GitHub"

  tags = var.tags
}

# Note: After deployment, you need to complete the GitHub connection in the AWS Console:
# 1. Go to AWS CodePipeline > Settings > Connections
# 2. Find the connection named "github-hackathons"
# 3. Click "Update pending connection" and authorize with GitHub
# 4. Once connected, the pipeline will automatically trigger on commits to the configured branch

# Store GitHub token in Secrets Manager
# Handle existing secrets gracefully to avoid conflicts
resource "aws_secretsmanager_secret" "github_token" {
  name = "${var.project_name}-github-token-${var.environment}"
  kms_key_id = var.kms_key_arn
  
  # Handle existing secrets that might be scheduled for deletion
  recovery_window_in_days = 0  # Allow immediate deletion if needed

  tags = var.tags
  
  lifecycle {
    # Ignore changes to recovery window to prevent conflicts
    ignore_changes = [recovery_window_in_days]
  }
}

resource "aws_secretsmanager_secret_version" "github_token" {
  secret_id     = aws_secretsmanager_secret.github_token.id
  secret_string = var.github_token != "" ? var.github_token : "placeholder-token-update-manually"

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Infrastructure step removed - Terraform is run locally, not in pipeline
# This eliminates the redundancy and circular dependency issues

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
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
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
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
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
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
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
        DetectChanges        = "true"  # Automatically triggers pipeline on GitHub commits
        OutputArtifactFormat = "CODE_ZIP"
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
      input_artifacts  = ["source_output"]
      output_artifacts = ["frontend_output"]

      configuration = {
        ProjectName = aws_codebuild_project.frontend.name
      }
    }
  }

  tags = var.tags
}
