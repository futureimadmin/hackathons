# CloudWatch Monitoring Module
# Task 23: Monitoring and Logging

# CloudWatch Dashboard for Data Pipeline
resource "aws_cloudwatch_dashboard" "data_pipeline" {
  dashboard_name = "${var.project_name}-data-pipeline"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DMS", "FullLoadThroughputRowsSource", { stat = "Sum" }],
            [".", "FullLoadThroughputRowsTarget", { stat = "Sum" }],
            [".", "CDCLatencySource", { stat = "Average" }],
            [".", "CDCLatencyTarget", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "DMS Replication Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Batch", "RunningJobs", { stat = "Average" }],
            [".", "SubmittedJobs", { stat = "Sum" }],
            [".", "FailedJobs", { stat = "Sum" }],
            [".", "SucceededJobs", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Batch Job Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Glue", "glue.driver.aggregate.numCompletedTasks", { stat = "Sum" }],
            [".", "glue.driver.aggregate.numFailedTasks", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Glue Crawler Metrics"
        }
      },
      {
        type = "log"
        properties = {
          query   = "SOURCE '/aws/batch/job' | fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20"
          region  = var.aws_region
          title   = "Recent Batch Job Errors"
        }
      }
    ]
  })
}

# CloudWatch Dashboard for API Performance
resource "aws_cloudwatch_dashboard" "api_performance" {
  dashboard_name = "${var.project_name}-api-performance"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", { stat = "Sum" }],
            [".", "4XXError", { stat = "Sum" }],
            [".", "5XXError", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "API Gateway Request Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Latency", { stat = "Average" }],
            [".", "IntegrationLatency", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "API Gateway Latency"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum" }],
            [".", "Errors", { stat = "Sum" }],
            [".", "Throttles", { stat = "Sum" }],
            [".", "Duration", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Lambda Function Metrics"
        }
      },
      {
        type = "log"
        properties = {
          query   = "SOURCE '/aws/lambda/*' | fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20"
          region  = var.aws_region
          title   = "Recent Lambda Errors"
        }
      }
    ]
  })
}

# CloudWatch Dashboard for ML Model Performance
resource "aws_cloudwatch_dashboard" "ml_performance" {
  dashboard_name = "${var.project_name}-ml-performance"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["${var.project_name}", "MarketIntelligence.ForecastAccuracy", { stat = "Average" }],
            [".", "MarketIntelligence.ModelTrainingTime", { stat = "Average" }],
            [".", "MarketIntelligence.PredictionLatency", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Market Intelligence Hub Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["${var.project_name}", "DemandInsights.SegmentationQuality", { stat = "Average" }],
            [".", "DemandInsights.CLVAccuracy", { stat = "Average" }],
            [".", "DemandInsights.ChurnPredictionAccuracy", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Demand Insights Engine Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["${var.project_name}", "Compliance.FraudDetectionRate", { stat = "Average" }],
            [".", "Compliance.HighRiskTransactions", { stat = "Sum" }],
            [".", "Compliance.PCIViolations", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Compliance Guardian Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["${var.project_name}", "RetailCopilot.ChatResponseTime", { stat = "Average" }],
            [".", "RetailCopilot.SQLGenerationSuccess", { stat = "Average" }],
            [".", "RetailCopilot.ConversationCount", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Retail Copilot Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["${var.project_name}", "GlobalMarket.TrendAccuracy", { stat = "Average" }],
            [".", "GlobalMarket.OpportunityScores", { stat = "Average" }],
            [".", "GlobalMarket.CompetitorAnalysisTime", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Global Market Pulse Metrics"
        }
      }
    ]
  })
}

# CloudWatch Alarms for DMS Replication
resource "aws_cloudwatch_metric_alarm" "dms_replication_lag" {
  alarm_name          = "${var.project_name}-dms-replication-lag"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CDCLatencySource"
  namespace           = "AWS/DMS"
  period              = 300
  statistic           = "Average"
  threshold           = 300000 # 5 minutes in milliseconds
  alarm_description   = "DMS replication lag exceeds 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}

# CloudWatch Alarms for Lambda Errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Lambda function errors exceed threshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}

# CloudWatch Alarms for API Gateway 5xx Errors
resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx" {
  alarm_name          = "${var.project_name}-api-gateway-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "API Gateway 5xx errors exceed threshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}

# CloudWatch Alarms for Batch Job Failures
resource "aws_cloudwatch_metric_alarm" "batch_job_failures" {
  alarm_name          = "${var.project_name}-batch-job-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FailedJobs"
  namespace           = "AWS/Batch"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Batch job failures detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-alerts"
  display_name      = "eCommerce AI Platform Alerts"
  kms_master_key_id = var.kms_key_id

  tags = {
    Name        = "${var.project_name}-alerts"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# SNS Topic Subscription (Email)
resource "aws_sns_topic_subscription" "alerts_email" {
  count     = length(var.alert_emails)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_emails[count.index]
}

# CloudWatch Log Groups with Retention
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = toset([
    "auth-service",
    "analytics-service",
    "market-intelligence-hub",
    "demand-insights-engine",
    "compliance-guardian",
    "retail-copilot",
    "global-market-pulse"
  ])

  name              = "/aws/lambda/${var.project_name}-${each.key}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = {
    Name        = "${var.project_name}-${each.key}-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "batch_logs" {
  name              = "/aws/batch/job"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = {
    Name        = "${var.project_name}-batch-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.project_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = {
    Name        = "${var.project_name}-api-gateway-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# CloudTrail for Audit Logging
resource "aws_cloudtrail" "audit_trail" {
  name                          = "${var.project_name}-audit-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = var.kms_key_id

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${var.data_lake_bucket_arn}/*"]
    }

    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function/*"]
    }
  }

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn

  tags = {
    Name        = "${var.project_name}-audit-trail"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# S3 Bucket for CloudTrail Logs
resource "aws_s3_bucket" "cloudtrail" {
  bucket = "${var.project_name}-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project_name}-cloudtrail-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_id
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# CloudWatch Log Group for CloudTrail
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.project_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = {
    Name        = "${var.project_name}-cloudtrail-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# IAM Role for CloudTrail to CloudWatch Logs
resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name = "${var.project_name}-cloudtrail-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-cloudtrail-cloudwatch-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name = "${var.project_name}-cloudtrail-cloudwatch-policy"
  role = aws_iam_role.cloudtrail_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      }
    ]
  })
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
