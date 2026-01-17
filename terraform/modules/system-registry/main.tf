# System Registry Module
# Task 24: System Registration for Extensibility

# DynamoDB Table for System Registry
resource "aws_dynamodb_table" "system_registry" {
  name           = "${var.project_name}-system-registry"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "system_id"
  stream_enabled = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "system_id"
    type = "S"
  }

  attribute {
    name = "system_name"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "SystemNameIndex"
    hash_key        = "system_name"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = {
    Name        = "${var.project_name}-system-registry"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Lambda Function for System Registration
resource "aws_lambda_function" "system_registration" {
  filename         = "${path.module}/lambda/system-registration.zip"
  function_name    = "${var.project_name}-system-registration"
  role            = aws_iam_role.system_registration.arn
  handler         = "handler.lambda_handler"
  source_code_hash = filebase64sha256("${path.module}/lambda/system-registration.zip")
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 512

  environment {
    variables = {
      REGISTRY_TABLE_NAME = aws_dynamodb_table.system_registry.name
      PROJECT_NAME        = var.project_name
      AWS_REGION          = var.aws_region
      KMS_KEY_ID          = var.kms_key_id
    }
  }

  tags = {
    Name        = "${var.project_name}-system-registration"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Lambda Function for Infrastructure Provisioning
resource "aws_lambda_function" "infrastructure_provisioner" {
  filename         = "${path.module}/lambda/infrastructure-provisioner.zip"
  function_name    = "${var.project_name}-infrastructure-provisioner"
  role            = aws_iam_role.infrastructure_provisioner.arn
  handler         = "handler.lambda_handler"
  source_code_hash = filebase64sha256("${path.module}/lambda/infrastructure-provisioner.zip")
  runtime         = "python3.11"
  timeout         = 900
  memory_size     = 1024

  environment {
    variables = {
      REGISTRY_TABLE_NAME = aws_dynamodb_table.system_registry.name
      PROJECT_NAME        = var.project_name
      AWS_REGION          = var.aws_region
      KMS_KEY_ID          = var.kms_key_id
      DATA_LAKE_BUCKET    = var.data_lake_bucket_name
    }
  }

  tags = {
    Name        = "${var.project_name}-infrastructure-provisioner"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# EventBridge Rule for DynamoDB Stream
resource "aws_lambda_event_source_mapping" "registry_stream" {
  event_source_arn  = aws_dynamodb_table.system_registry.stream_arn
  function_name     = aws_lambda_function.infrastructure_provisioner.arn
  starting_position = "LATEST"

  filter_criteria {
    filter {
      pattern = jsonencode({
        eventName = ["INSERT", "MODIFY"]
        dynamodb = {
          NewImage = {
            status = {
              S = ["pending_provisioning"]
            }
          }
        }
      })
    }
  }
}

# IAM Role for System Registration Lambda
resource "aws_iam_role" "system_registration" {
  name = "${var.project_name}-system-registration-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-system-registration-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy" "system_registration" {
  name = "${var.project_name}-system-registration-policy"
  role = aws_iam_role.system_registration.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.system_registry.arn,
          "${aws_dynamodb_table.system_registry.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# IAM Role for Infrastructure Provisioner Lambda
resource "aws_iam_role" "infrastructure_provisioner" {
  name = "${var.project_name}-infrastructure-provisioner-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-infrastructure-provisioner-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy" "infrastructure_provisioner" {
  name = "${var.project_name}-infrastructure-provisioner-policy"
  role = aws_iam_role.infrastructure_provisioner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:DescribeStream",
          "dynamodb:ListStreams"
        ]
        Resource = [
          aws_dynamodb_table.system_registry.arn,
          "${aws_dynamodb_table.system_registry.arn}/stream/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:PutBucketPolicy",
          "s3:PutBucketVersioning",
          "s3:PutEncryptionConfiguration",
          "s3:PutBucketNotification",
          "s3:PutLifecycleConfiguration"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "glue:CreateDatabase",
          "glue:CreateCrawler",
          "glue:StartCrawler"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dms:CreateReplicationTask",
          "dms:StartReplicationTask"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutRule",
          "events:PutTargets"
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
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arn
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = [
              "glue.amazonaws.com",
              "dms.amazonaws.com",
              "events.amazonaws.com"
            ]
          }
        }
      }
    ]
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "system_registration" {
  name              = "/aws/lambda/${aws_lambda_function.system_registration.function_name}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = {
    Name        = "${var.project_name}-system-registration-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "infrastructure_provisioner" {
  name              = "/aws/lambda/${aws_lambda_function.infrastructure_provisioner.function_name}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = {
    Name        = "${var.project_name}-infrastructure-provisioner-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
