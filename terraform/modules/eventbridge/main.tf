# EventBridge Module for Data Pipeline Orchestration
# Creates rules to trigger Batch jobs on S3 events

# EventBridge Rule: Raw Bucket Events → Raw-to-Curated Job
resource "aws_cloudwatch_event_rule" "raw_bucket_events" {
  for_each = var.systems

  name        = "${var.project_name}-${each.key}-raw-events"
  description = "Trigger raw-to-curated processing for ${each.key} system"
  
  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = ["${each.key}-raw-${var.aws_account_id}"]
      }
      object = {
        key = [{
          suffix = ".parquet"
        }]
      }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "raw_to_curated" {
  for_each = var.systems

  rule      = aws_cloudwatch_event_rule.raw_bucket_events[each.key].name
  target_id = "BatchJobTarget"
  arn       = var.batch_job_queue_arn
  role_arn  = aws_iam_role.eventbridge.arn

  batch_target {
    job_definition = var.raw_to_curated_job_definition_arn
    job_name       = "${each.key}-raw-to-curated"
    
    array_properties {
      size = 1
    }
  }

  input_transformer {
    input_paths = {
      bucket = "$.detail.bucket.name"
      key    = "$.detail.object.key"
    }
    
    input_template = jsonencode({
      Parameters = {
        Bucket = "<bucket>"
        Key    = "<key>"
      }
    })
  }
}

# EventBridge Rule: Curated Bucket Events → Curated-to-Prod Job
resource "aws_cloudwatch_event_rule" "curated_bucket_events" {
  for_each = var.systems

  name        = "${var.project_name}-${each.key}-curated-events"
  description = "Trigger curated-to-prod processing for ${each.key} system"
  
  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = ["${each.key}-curated-${var.aws_account_id}"]
      }
      object = {
        key = [{
          suffix = ".parquet"
        }]
      }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "curated_to_prod" {
  for_each = var.systems

  rule      = aws_cloudwatch_event_rule.curated_bucket_events[each.key].name
  target_id = "BatchJobTarget"
  arn       = var.batch_job_queue_arn
  role_arn  = aws_iam_role.eventbridge.arn

  batch_target {
    job_definition = var.curated_to_prod_job_definition_arn
    job_name       = "${each.key}-curated-to-prod"
    
    array_properties {
      size = 1
    }
  }

  input_transformer {
    input_paths = {
      bucket = "$.detail.bucket.name"
      key    = "$.detail.object.key"
    }
    
    input_template = jsonencode({
      Parameters = {
        Bucket = "<bucket>"
        Key    = "<key>"
      }
    })
  }
}

# S3 Event Notifications (Enable EventBridge notifications on buckets)
resource "aws_s3_bucket_notification" "raw_bucket" {
  for_each = var.systems

  bucket      = "${each.key}-raw-${var.aws_account_id}"
  eventbridge = true
}

resource "aws_s3_bucket_notification" "curated_bucket" {
  for_each = var.systems

  bucket      = "${each.key}-curated-${var.aws_account_id}"
  eventbridge = true
}
