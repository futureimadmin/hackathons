# AWS Athena Module - Workgroup and Query Configuration
# Creates Athena workgroup for analytics queries

# S3 bucket for Athena query results (single bucket for all systems)
resource "aws_s3_bucket" "query_results" {
  bucket = var.query_results_bucket_name

  tags = merge(
    var.tags,
    {
      Name    = var.query_results_bucket_name
      Purpose = "Athena query results for all AI systems"
    }
  )
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Enable versioning for query results bucket
resource "aws_s3_bucket_versioning" "query_results" {
  bucket = aws_s3_bucket.query_results.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for query results bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "query_results" {
  bucket = aws_s3_bucket.query_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to query results bucket
resource "aws_s3_bucket_public_access_block" "query_results" {
  bucket = aws_s3_bucket.query_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy to allow Athena service and Lambda role access
resource "aws_s3_bucket_policy" "query_results" {
  bucket = aws_s3_bucket.query_results.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAthenaServiceAccess"
        Effect = "Allow"
        Principal = {
          Service = "athena.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.query_results.arn,
          "${aws_s3_bucket.query_results.arn}/*"
        ]
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.query_results]
}

# Lifecycle policy for query results
resource "aws_s3_bucket_lifecycle_configuration" "query_results" {
  bucket = aws_s3_bucket.query_results.id

  rule {
    id     = "delete-old-query-results"
    status = "Enabled"

    expiration {
      days = var.query_results_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# Athena workgroup
resource "aws_athena_workgroup" "analytics" {
  name        = var.workgroup_name
  description = "Workgroup for eCommerce analytics queries"
  state       = "ENABLED"

  configuration {
    # Query result location
    result_configuration {
      output_location = "s3://${aws_s3_bucket.query_results.bucket}/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }

    # Enforce workgroup configuration
    enforce_workgroup_configuration = true

    # Enable CloudWatch metrics
    publish_cloudwatch_metrics_enabled = true

    # Data usage control - commented out due to Terraform type issues
    # bytes_scanned_cutoff_per_query = var.bytes_scanned_cutoff

    # Engine version
    engine_version {
      selected_engine_version = "AUTO"
    }

    # Requester pays disabled
    requester_pays_enabled = false
  }

  tags = merge(
    var.tags,
    {
      Name = var.workgroup_name
    }
  )
}

# CloudWatch Log Group for Athena queries
resource "aws_cloudwatch_log_group" "athena_queries" {
  name              = "/aws/athena/${var.workgroup_name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.workgroup_name}-logs"
    }
  )
}

# CloudWatch alarm for high query costs
resource "aws_cloudwatch_metric_alarm" "high_query_cost" {
  alarm_name          = "${var.workgroup_name}-high-query-cost"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DataScannedInBytes"
  namespace           = "AWS/Athena"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.high_cost_threshold_bytes
  alarm_description   = "Alert when Athena query scans too much data"
  alarm_actions       = var.alarm_actions

  dimensions = {
    WorkGroup = aws_athena_workgroup.analytics.name
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.workgroup_name}-high-cost-alarm"
    }
  )
}

# CloudWatch alarm for query failures
resource "aws_cloudwatch_metric_alarm" "query_failures" {
  alarm_name          = "${var.workgroup_name}-query-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FailedQueries"
  namespace           = "AWS/Athena"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.failure_threshold
  alarm_description   = "Alert when Athena queries fail"
  alarm_actions       = var.alarm_actions

  dimensions = {
    WorkGroup = aws_athena_workgroup.analytics.name
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.workgroup_name}-failure-alarm"
    }
  )
}

# Named queries for common analytics tasks
resource "aws_athena_named_query" "sample_orders_query" {
  name        = "sample-orders-query"
  description = "Sample query to retrieve recent orders"
  database    = var.sample_database_name
  workgroup   = aws_athena_workgroup.analytics.name

  query = <<-EOT
    SELECT 
        order_id,
        customer_id,
        order_total,
        order_date,
        order_status
    FROM ${var.sample_database_name}.ecommerce_orders_prod
    WHERE year = YEAR(CURRENT_DATE)
        AND month = MONTH(CURRENT_DATE)
        AND order_status = 'completed'
    ORDER BY order_date DESC
    LIMIT 100;
  EOT
}

resource "aws_athena_named_query" "daily_sales_summary" {
  name        = "daily-sales-summary"
  description = "Daily sales summary with aggregations"
  database    = var.sample_database_name
  workgroup   = aws_athena_workgroup.analytics.name

  query = <<-EOT
    SELECT 
        DATE(order_date) as sale_date,
        COUNT(DISTINCT order_id) as order_count,
        COUNT(DISTINCT customer_id) as customer_count,
        SUM(order_total) as total_revenue,
        AVG(order_total) as avg_order_value
    FROM ${var.sample_database_name}.ecommerce_orders_prod
    WHERE year = YEAR(CURRENT_DATE)
        AND month = MONTH(CURRENT_DATE)
    GROUP BY DATE(order_date)
    ORDER BY sale_date DESC;
  EOT
}

resource "aws_athena_named_query" "top_products" {
  name        = "top-products-by-revenue"
  description = "Top 20 products by revenue"
  database    = var.sample_database_name
  workgroup   = aws_athena_workgroup.analytics.name

  query = <<-EOT
    SELECT 
        p.product_id,
        p.name as product_name,
        p.category_id,
        COUNT(DISTINCT oi.order_id) as order_count,
        SUM(oi.quantity) as units_sold,
        SUM(oi.total) as total_revenue
    FROM ${var.sample_database_name}.ecommerce_order_items_prod oi
    JOIN ${var.sample_database_name}.ecommerce_products_prod p
        ON oi.product_id = p.product_id
    WHERE oi.year = YEAR(CURRENT_DATE)
        AND oi.month = MONTH(CURRENT_DATE)
    GROUP BY p.product_id, p.name, p.category_id
    ORDER BY total_revenue DESC
    LIMIT 20;
  EOT
}

resource "aws_athena_named_query" "customer_lifetime_value" {
  name        = "customer-lifetime-value"
  description = "Calculate customer lifetime value"
  database    = var.sample_database_name
  workgroup   = aws_athena_workgroup.analytics.name

  query = <<-EOT
    SELECT 
        customer_id,
        COUNT(DISTINCT order_id) as total_orders,
        SUM(order_total) as lifetime_value,
        AVG(order_total) as avg_order_value,
        MIN(order_date) as first_order_date,
        MAX(order_date) as last_order_date,
        DATE_DIFF('day', MIN(order_date), MAX(order_date)) as customer_age_days
    FROM ${var.sample_database_name}.ecommerce_orders_prod
    WHERE order_status IN ('completed', 'delivered')
    GROUP BY customer_id
    HAVING COUNT(DISTINCT order_id) > 1
    ORDER BY lifetime_value DESC
    LIMIT 100;
  EOT
}
