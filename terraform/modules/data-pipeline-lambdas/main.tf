# Data Pipeline Lambda Functions Module
# Creates Lambda functions for raw-to-curated and curated-to-prod processing
# Uses container images for large dependencies (pandas, numpy, scikit-learn)

# IAM Role for Lambda Functions
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-data-pipeline-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for Lambda Functions
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-data-pipeline-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::ecommerce-raw-${var.aws_account_id}/*",
          "arn:aws:s3:::ecommerce-curated-${var.aws_account_id}/*",
          "arn:aws:s3:::*-prod-${var.aws_account_id}/*",
          "arn:aws:s3:::ecommerce-raw-${var.aws_account_id}",
          "arn:aws:s3:::ecommerce-curated-${var.aws_account_id}",
          "arn:aws:s3:::*-prod-${var.aws_account_id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      },
      {
        Effect = "Allow"
        Action = [
          "glue:StartCrawler",
          "glue:GetCrawler"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ECR Repository for Raw to Curated Lambda
resource "aws_ecr_repository" "raw_to_curated" {
  name                 = "${var.project_name}-raw-to-curated"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-raw-to-curated"
    }
  )
}

# ECR Repository for Curated to Prod Lambda
resource "aws_ecr_repository" "curated_to_prod" {
  name                 = "${var.project_name}-curated-to-prod"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-curated-to-prod"
    }
  )
}

# Raw to Curated Lambda Function (Container Image)
resource "aws_lambda_function" "raw_to_curated" {
  function_name = "${var.project_name}-raw-to-curated"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.raw_to_curated.repository_url}:latest"
  timeout       = 900  # 15 minutes
  memory_size   = 3008  # 3 GB for pandas operations

  environment {
    variables = {
      CURATED_BUCKET = "ecommerce-curated-${var.aws_account_id}"
      LOG_LEVEL      = "INFO"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-raw-to-curated"
    }
  )

  # Ignore changes to image_uri as it will be updated by CI/CD
  lifecycle {
    ignore_changes = [image_uri]
  }
}

# Curated to Prod Lambda Function (Container Image)
resource "aws_lambda_function" "curated_to_prod" {
  function_name = "${var.project_name}-curated-to-prod"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.curated_to_prod.repository_url}:latest"
  timeout       = 900  # 15 minutes
  memory_size   = 3008  # 3 GB for AI processing

  environment {
    variables = {
      CURATED_BUCKET = "ecommerce-curated-${var.aws_account_id}"
      ACCOUNT_ID     = var.aws_account_id
      LOG_LEVEL      = "INFO"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-curated-to-prod"
    }
  )

  # Ignore changes to image_uri as it will be updated by CI/CD
  lifecycle {
    ignore_changes = [image_uri]
  }
}

# S3 Trigger Permission for Raw Bucket -> Raw to Curated Lambda
resource "aws_lambda_permission" "allow_raw_bucket" {
  statement_id  = "AllowExecutionFromS3RawBucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.raw_to_curated.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::ecommerce-raw-${var.aws_account_id}"
}

# S3 Trigger Permission for Curated Bucket -> Curated to Prod Lambda
resource "aws_lambda_permission" "allow_curated_bucket" {
  statement_id  = "AllowExecutionFromS3CuratedBucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.curated_to_prod.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::ecommerce-curated-${var.aws_account_id}"
}

# S3 Bucket Notification for Raw Bucket
resource "aws_s3_bucket_notification" "raw_bucket_notification" {
  bucket = "ecommerce-raw-${var.aws_account_id}"

  lambda_function {
    lambda_function_arn = aws_lambda_function.raw_to_curated.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".parquet"
  }

  depends_on = [aws_lambda_permission.allow_raw_bucket]
}

# S3 Bucket Notification for Curated Bucket
resource "aws_s3_bucket_notification" "curated_bucket_notification" {
  bucket = "ecommerce-curated-${var.aws_account_id}"

  lambda_function {
    lambda_function_arn = aws_lambda_function.curated_to_prod.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".parquet"
  }

  depends_on = [aws_lambda_permission.allow_curated_bucket]
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "raw_to_curated" {
  name              = "/aws/lambda/${aws_lambda_function.raw_to_curated.function_name}"
  retention_in_days = 7

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "curated_to_prod" {
  name              = "/aws/lambda/${aws_lambda_function.curated_to_prod.function_name}"
  retention_in_days = 7

  tags = var.tags
}
