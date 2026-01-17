# IAM Roles and Policies for AWS Batch

# Batch Service Role
resource "aws_iam_role" "batch_service" {
  name = "${var.project_name}-batch-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "batch.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "batch_service" {
  role       = aws_iam_role.batch_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

# Batch Instance Role (for EC2 compute)
resource "aws_iam_role" "batch_instance" {
  name = "${var.project_name}-batch-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "batch_instance_ecs" {
  role       = aws_iam_role.batch_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "batch_instance" {
  name = "${var.project_name}-batch-instance-profile"
  role = aws_iam_role.batch_instance.name

  tags = var.tags
}

# Batch Job Role (permissions for the job itself)
resource "aws_iam_role" "batch_job" {
  name = "${var.project_name}-batch-job-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# Batch Job Policy - S3 Access
resource "aws_iam_role_policy" "batch_job_s3" {
  name = "${var.project_name}-batch-job-s3-policy"
  role = aws_iam_role.batch_job.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::*-raw-*",
          "arn:aws:s3:::*-raw-*/*",
          "arn:aws:s3:::*-curated-*",
          "arn:aws:s3:::*-curated-*/*",
          "arn:aws:s3:::*-prod-*",
          "arn:aws:s3:::*-prod-*/*",
          "arn:aws:s3:::*-errors-*",
          "arn:aws:s3:::*-errors-*/*"
        ]
      }
    ]
  })
}

# Batch Job Policy - Glue Access
resource "aws_iam_role_policy" "batch_job_glue" {
  name = "${var.project_name}-batch-job-glue-policy"
  role = aws_iam_role.batch_job.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:StartCrawler",
          "glue:GetCrawler",
          "glue:GetCrawlerMetrics"
        ]
        Resource = "*"
      }
    ]
  })
}

# Batch Job Policy - CloudWatch Logs
resource "aws_iam_role_policy" "batch_job_logs" {
  name = "${var.project_name}-batch-job-logs-policy"
  role = aws_iam_role.batch_job.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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

# Batch Job Policy - Secrets Manager
resource "aws_iam_role_policy" "batch_job_secrets" {
  name = "${var.project_name}-batch-job-secrets-policy"
  role = aws_iam_role.batch_job.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.project_name}/*"
      }
    ]
  })
}

# Batch Job Policy - KMS
resource "aws_iam_role_policy" "batch_job_kms" {
  name = "${var.project_name}-batch-job-kms-policy"
  role = aws_iam_role.batch_job.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# Batch Execution Role (for Fargate)
resource "aws_iam_role" "batch_execution" {
  name = "${var.project_name}-batch-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "batch_execution" {
  role       = aws_iam_role.batch_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Batch Execution Policy - ECR Access
resource "aws_iam_role_policy" "batch_execution_ecr" {
  name = "${var.project_name}-batch-execution-ecr-policy"
  role = aws_iam_role.batch_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# Batch Execution Policy - Secrets Manager
resource "aws_iam_role_policy" "batch_execution_secrets" {
  name = "${var.project_name}-batch-execution-secrets-policy"
  role = aws_iam_role.batch_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.project_name}/*"
      }
    ]
  })
}
