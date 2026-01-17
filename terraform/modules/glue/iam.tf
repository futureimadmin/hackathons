# IAM Roles and Policies for Glue

# IAM Role for Glue Crawler
resource "aws_iam_role" "glue_crawler_role" {
  name = "${var.system_name}-glue-crawler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name   = "${var.system_name}-glue-crawler-role"
      System = var.system_name
    }
  )
}

# Attach AWS managed policy for Glue service
resource "aws_iam_role_policy_attachment" "glue_service_policy" {
  role       = aws_iam_role.glue_crawler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Custom policy for S3 access
resource "aws_iam_role_policy" "glue_s3_policy" {
  name = "${var.system_name}-glue-s3-policy"
  role = aws_iam_role.glue_crawler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.prod_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.prod_bucket_name}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:*:*:/aws-glue/*"
        ]
      }
    ]
  })
}

# IAM Role for Lambda function (if enabled)
resource "aws_iam_role" "lambda_trigger_role" {
  count = var.enable_lambda_trigger ? 1 : 0

  name = "${var.system_name}-lambda-trigger-crawler-role"

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

  tags = merge(
    var.tags,
    {
      Name   = "${var.system_name}-lambda-trigger-crawler-role"
      System = var.system_name
    }
  )
}

# Attach AWS managed policy for Lambda basic execution
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  count = var.enable_lambda_trigger ? 1 : 0

  role       = aws_iam_role.lambda_trigger_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom policy for Lambda to start Glue Crawler
resource "aws_iam_role_policy" "lambda_glue_policy" {
  count = var.enable_lambda_trigger ? 1 : 0

  name = "${var.system_name}-lambda-glue-policy"
  role = aws_iam_role.lambda_trigger_role[0].id

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
        Resource = [
          aws_glue_crawler.prod_crawler.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.prod_bucket_name}",
          "arn:aws:s3:::${var.prod_bucket_name}/*"
        ]
      }
    ]
  })
}
