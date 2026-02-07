# EventBridge Module for Data Pipeline Orchestration
# Creates rules to trigger Batch jobs on S3 events
# Updated for shared raw and curated buckets

# EventBridge Rule: Shared Raw Bucket Events → Raw-to-Curated Job
resource "aws_cloudwatch_event_rule" "raw_bucket_events" {
  name        = "ecommerce-raw-events"
  description = "Trigger raw-to-curated processing for shared raw bucket"
  
  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = ["ecommerce-raw-${var.aws_account_id}"]
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
  rule      = aws_cloudwatch_event_rule.raw_bucket_events.name
  target_id = "BatchJobTarget"
  arn       = var.batch_job_queue_arn
  role_arn  = aws_iam_role.eventbridge.arn

  batch_target {
    job_definition = var.raw_to_curated_job_definition_arn
    job_name       = "ecommerce-raw-to-curated"
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

# EventBridge Rule: Shared Curated Bucket Events → Curated-to-Prod Jobs (one per system)
resource "aws_cloudwatch_event_rule" "curated_bucket_events" {
  for_each = var.systems

  name        = "${each.key}-curated-events"
  description = "Trigger curated-to-prod processing for ${each.key} system"
  
  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = ["ecommerce-curated-${var.aws_account_id}"]
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
        System = each.key
      }
    })
  }
}
