# IAM Role for EventBridge to invoke Batch jobs

resource "aws_iam_role" "eventbridge" {
  name = "${var.project_name}-eventbridge-batch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "eventbridge_batch" {
  name = "${var.project_name}-eventbridge-batch-policy"
  role = aws_iam_role.eventbridge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "batch:SubmitJob"
        ]
        Resource = [
          var.raw_to_curated_job_definition_arn,
          var.curated_to_prod_job_definition_arn,
          var.batch_job_queue_arn
        ]
      }
    ]
  })
}
