# AWS Batch Module
# Creates compute environment, job queue, and job definitions for data processing

# Compute Environment
resource "aws_batch_compute_environment" "data_processing" {
  compute_environment_name = "${var.project_name}-data-processing"
  type                     = "MANAGED"
  state                    = "ENABLED"
  service_role             = aws_iam_role.batch_service.arn

  compute_resources {
    type                = var.compute_type
    allocation_strategy = "BEST_FIT_PROGRESSIVE"
    
    min_vcpus     = var.min_vcpus
    max_vcpus     = var.max_vcpus
    desired_vcpus = var.desired_vcpus
    
    instance_type = var.instance_types
    
    subnets         = var.subnet_ids
    security_group_ids = var.security_group_ids
    
    instance_role = aws_iam_instance_profile.batch_instance.arn
    
    tags = merge(
      var.tags,
      {
        Name = "${var.project_name}-batch-compute"
      }
    )
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      compute_resources[0].desired_vcpus
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.batch_service]
}

# Job Queue
resource "aws_batch_job_queue" "data_processing" {
  name     = "${var.project_name}-data-processing-queue"
  state    = "ENABLED"
  priority = 1

  compute_environments = [
    aws_batch_compute_environment.data_processing.arn
  ]

  tags = var.tags
}

# Job Definition: Raw to Curated
resource "aws_batch_job_definition" "raw_to_curated" {
  name = "${var.project_name}-raw-to-curated"
  type = "container"

  platform_capabilities = [var.compute_type == "FARGATE" ? "FARGATE" : "EC2"]

  container_properties = jsonencode({
    image = var.ecr_image_uri
    
    jobRoleArn       = aws_iam_role.batch_job.arn
    executionRoleArn = aws_iam_role.batch_execution.arn
    
    resourceRequirements = var.compute_type == "FARGATE" ? [
      { type = "VCPU", value = tostring(var.raw_to_curated_vcpus) },
      { type = "MEMORY", value = tostring(var.raw_to_curated_memory) }
    ] : null
    
    vcpus  = var.compute_type == "EC2" ? var.raw_to_curated_vcpus : null
    memory = var.compute_type == "EC2" ? var.raw_to_curated_memory : null
    
    command = ["python", "-m", "src.processors.raw_to_curated"]
    
    environment = [
      {
        name  = "AWS_REGION"
        value = var.aws_region
      },
      {
        name  = "LOG_LEVEL"
        value = var.log_level
      },
      {
        name  = "DEDUPLICATION_ENABLED"
        value = "true"
      },
      {
        name  = "COMPLIANCE_PCI_DSS_ENABLED"
        value = "true"
      }
    ]
    
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.batch_jobs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "raw-to-curated"
      }
    }
  })

  retry_strategy {
    attempts = var.retry_attempts
    
    evaluate_on_exit {
      action       = "RETRY"
      on_status_reason = "Task failed to start"
    }
    
    evaluate_on_exit {
      action       = "EXIT"
      on_status_reason = "Essential container exited"
    }
  }

  timeout {
    attempt_duration_seconds = var.raw_to_curated_timeout
  }

  tags = var.tags
}

# Job Definition: Curated to Prod
resource "aws_batch_job_definition" "curated_to_prod" {
  name = "${var.project_name}-curated-to-prod"
  type = "container"

  platform_capabilities = [var.compute_type == "FARGATE" ? "FARGATE" : "EC2"]

  container_properties = jsonencode({
    image = var.ecr_image_uri
    
    jobRoleArn       = aws_iam_role.batch_job.arn
    executionRoleArn = aws_iam_role.batch_execution.arn
    
    resourceRequirements = var.compute_type == "FARGATE" ? [
      { type = "VCPU", value = tostring(var.curated_to_prod_vcpus) },
      { type = "MEMORY", value = tostring(var.curated_to_prod_memory) }
    ] : null
    
    vcpus  = var.compute_type == "EC2" ? var.curated_to_prod_vcpus : null
    memory = var.compute_type == "EC2" ? var.curated_to_prod_memory : null
    
    command = ["python", "-m", "src.processors.curated_to_prod"]
    
    environment = [
      {
        name  = "AWS_REGION"
        value = var.aws_region
      },
      {
        name  = "LOG_LEVEL"
        value = var.log_level
      },
      {
        name  = "GLUE_TRIGGER_CRAWLER"
        value = "true"
      }
    ]
    
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.batch_jobs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "curated-to-prod"
      }
    }
  })

  retry_strategy {
    attempts = var.retry_attempts
    
    evaluate_on_exit {
      action       = "RETRY"
      on_status_reason = "Task failed to start"
    }
    
    evaluate_on_exit {
      action       = "EXIT"
      on_status_reason = "Essential container exited"
    }
  }

  timeout {
    attempt_duration_seconds = var.curated_to_prod_timeout
  }

  tags = var.tags
}

# CloudWatch Log Group for Batch Jobs
resource "aws_cloudwatch_log_group" "batch_jobs" {
  name              = "/aws/batch/${var.project_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# ECR Repository for Docker Images
resource "aws_ecr_repository" "data_processor" {
  name                 = "${var.project_name}-data-processor"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_id
  }

  lifecycle {
    prevent_destroy = false
  }

  tags = var.tags
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "data_processor" {
  repository = aws_ecr_repository.data_processor.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
