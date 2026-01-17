# AWS Glue Module - Data Catalog and Crawlers
# Creates Glue databases and crawlers for each system

# Glue Database for each system
resource "aws_glue_catalog_database" "system_database" {
  name        = var.database_name
  description = "Glue database for ${var.system_name} - contains tables from prod bucket"

  tags = merge(
    var.tags,
    {
      Name   = var.database_name
      System = var.system_name
    }
  )
}

# Glue Crawler for prod bucket
resource "aws_glue_crawler" "prod_crawler" {
  name          = "${var.system_name}-crawler"
  role          = var.crawler_role_arn
  database_name = aws_glue_catalog_database.system_database.name
  description   = "Crawler for ${var.system_name} production data"

  s3_target {
    path = "s3://${var.prod_bucket_name}/"
  }

  # Schema change policy
  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  # Table grouping policy - combine compatible schemas
  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
  })

  # Schedule - run every 6 hours as backup (also triggered on-demand)
  schedule = var.crawler_schedule

  tags = merge(
    var.tags,
    {
      Name   = "${var.system_name}-crawler"
      System = var.system_name
    }
  )
}

# CloudWatch Log Group for Crawler
resource "aws_cloudwatch_log_group" "crawler_logs" {
  name              = "/aws-glue/crawlers/${var.system_name}-crawler"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name   = "${var.system_name}-crawler-logs"
      System = var.system_name
    }
  )
}

# Lambda function to trigger crawler after prod data write
resource "aws_lambda_function" "trigger_crawler" {
  count = var.enable_lambda_trigger ? 1 : 0

  filename         = var.lambda_zip_path
  function_name    = "${var.system_name}-trigger-crawler"
  role            = var.lambda_role_arn
  handler         = "index.handler"
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  runtime         = "python3.11"
  timeout         = 60
  memory_size     = 256

  environment {
    variables = {
      CRAWLER_NAME = aws_glue_crawler.prod_crawler.name
      LOG_LEVEL    = var.log_level
    }
  }

  tags = merge(
    var.tags,
    {
      Name   = "${var.system_name}-trigger-crawler"
      System = var.system_name
    }
  )
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  count = var.enable_lambda_trigger ? 1 : 0

  name              = "/aws/lambda/${var.system_name}-trigger-crawler"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name   = "${var.system_name}-trigger-crawler-logs"
      System = var.system_name
    }
  )
}

# Lambda permission for S3 to invoke
resource "aws_lambda_permission" "allow_s3" {
  count = var.enable_lambda_trigger ? 1 : 0

  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger_crawler[0].function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.prod_bucket_name}"
}

# S3 bucket notification to trigger Lambda
resource "aws_s3_bucket_notification" "prod_bucket_notification" {
  count = var.enable_lambda_trigger ? 1 : 0

  bucket = var.prod_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.trigger_crawler[0].arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "ecommerce/"
    filter_suffix       = ".parquet"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# CloudWatch alarm for crawler failures
resource "aws_cloudwatch_metric_alarm" "crawler_failure" {
  alarm_name          = "${var.system_name}-crawler-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "glue.driver.aggregate.numFailedTasks"
  namespace           = "Glue"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert when Glue crawler fails"
  alarm_actions       = var.alarm_actions

  dimensions = {
    JobName = aws_glue_crawler.prod_crawler.name
  }

  tags = merge(
    var.tags,
    {
      Name   = "${var.system_name}-crawler-failure-alarm"
      System = var.system_name
    }
  )
}
