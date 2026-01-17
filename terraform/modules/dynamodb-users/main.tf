# DynamoDB Table for User Authentication
# Stores user credentials and profile information

resource "aws_dynamodb_table" "users" {
  name           = var.table_name
  billing_mode   = var.billing_mode
  hash_key       = "userId"
  
  # Provisioned capacity (only used if billing_mode = "PROVISIONED")
  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null

  # Primary key
  attribute {
    name = "userId"
    type = "S"
  }

  # GSI for email lookup
  attribute {
    name = "email"
    type = "S"
  }

  # Global Secondary Index for querying by email
  global_secondary_index {
    name            = "email-index"
    hash_key        = "email"
    projection_type = "ALL"
    
    read_capacity  = var.billing_mode == "PROVISIONED" ? var.gsi_read_capacity : null
    write_capacity = var.billing_mode == "PROVISIONED" ? var.gsi_write_capacity : null
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  # TTL for reset tokens (optional)
  ttl {
    attribute_name = "resetTokenExpiry"
    enabled        = true
  }

  # Enable streams for audit logging
  stream_enabled   = var.enable_streams
  stream_view_type = var.enable_streams ? "NEW_AND_OLD_IMAGES" : null

  tags = merge(
    var.tags,
    {
      Name = var.table_name
    }
  )
}

# CloudWatch alarm for read capacity
resource "aws_cloudwatch_metric_alarm" "read_capacity" {
  count = var.billing_mode == "PROVISIONED" ? 1 : 0

  alarm_name          = "${var.table_name}-read-capacity-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ConsumedReadCapacityUnits"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.read_capacity * 240 # 80% of capacity over 5 minutes
  alarm_description   = "Alert when DynamoDB read capacity is high"
  alarm_actions       = var.alarm_actions

  dimensions = {
    TableName = aws_dynamodb_table.users.name
  }

  tags = var.tags
}

# CloudWatch alarm for write capacity
resource "aws_cloudwatch_metric_alarm" "write_capacity" {
  count = var.billing_mode == "PROVISIONED" ? 1 : 0

  alarm_name          = "${var.table_name}-write-capacity-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ConsumedWriteCapacityUnits"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.write_capacity * 240 # 80% of capacity over 5 minutes
  alarm_description   = "Alert when DynamoDB write capacity is high"
  alarm_actions       = var.alarm_actions

  dimensions = {
    TableName = aws_dynamodb_table.users.name
  }

  tags = var.tags
}

# CloudWatch alarm for throttled requests
resource "aws_cloudwatch_metric_alarm" "throttled_requests" {
  alarm_name          = "${var.table_name}-throttled-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UserErrors"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Alert when DynamoDB requests are throttled"
  alarm_actions       = var.alarm_actions

  dimensions = {
    TableName = aws_dynamodb_table.users.name
  }

  tags = var.tags
}
