terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# DMS Subnet Group
resource "aws_dms_replication_subnet_group" "main" {
  replication_subnet_group_id          = "${var.project_name}-${var.environment}-dms-subnet-group"
  replication_subnet_group_description = "DMS replication subnet group for ${var.project_name}"
  subnet_ids                           = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-dms-subnet-group"
      Environment = var.environment
    }
  )
}

# DMS Replication Instance
resource "aws_dms_replication_instance" "main" {
  replication_instance_id      = "${var.project_name}-${var.environment}-replication-instance"
  replication_instance_class   = var.replication_instance_class
  allocated_storage            = var.allocated_storage
  multi_az                     = var.multi_az
  engine_version               = "3.5.4"
  auto_minor_version_upgrade   = true
  publicly_accessible          = true  # Changed to true for direct public IP connection
  replication_subnet_group_id  = aws_dms_replication_subnet_group.main.id
  vpc_security_group_ids       = var.security_group_ids
  kms_key_arn                  = var.kms_key_arn

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-replication-instance"
      Environment = var.environment
    }
  )

  depends_on = [
    aws_dms_replication_subnet_group.main
  ]
}

# Retrieve source database password from Secrets Manager
data "aws_secretsmanager_secret_version" "source_password" {
  count     = var.source_password_secret_arn != null && var.source_password_secret_arn != "" ? 1 : 0
  secret_id = var.source_password_secret_arn
}

# Source Endpoint (On-Premise MySQL)
resource "aws_dms_endpoint" "source" {
  endpoint_id   = "${var.project_name}-${var.environment}-source-mysql"
  endpoint_type = "source"
  engine_name   = "mysql"
  
  server_name   = var.source_endpoint_config.server_name
  port          = var.source_endpoint_config.port
  username      = var.source_endpoint_config.username
  password      = var.source_password_secret_arn != null && var.source_password_secret_arn != "" ? data.aws_secretsmanager_secret_version.source_password[0].secret_string : "PLACEHOLDER_PASSWORD"
  database_name = var.source_endpoint_config.database_name
  ssl_mode      = var.source_endpoint_config.ssl_mode

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-source-mysql"
      Environment = var.environment
    }
  )
}

# Target Endpoints (S3 buckets) - Create one for each system
resource "aws_dms_endpoint" "target" {
  for_each = var.target_s3_buckets

  endpoint_id   = "${var.project_name}-${var.environment}-target-${each.key}"
  endpoint_type = "target"
  engine_name   = "s3"
  
  s3_settings {
    bucket_name             = each.value
    bucket_folder           = ""
    compression_type        = "GZIP"
    data_format             = "parquet"
    parquet_version         = "parquet-2-0"
    enable_statistics       = true
    include_op_for_full_load = true
    cdc_path                = "cdc"
    timestamp_column_name   = "dms_timestamp"
    parquet_timestamp_in_millisecond = true
    encryption_mode         = "SSE_KMS"
    server_side_encryption_kms_key_id = var.kms_key_arn
    service_access_role_arn = aws_iam_role.dms_s3_role.arn
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-target-${each.key}"
      Environment = var.environment
      System      = each.key
    }
  )
}

# IAM Role for DMS to access S3
resource "aws_iam_role" "dms_s3_role" {
  name = "${var.project_name}-${var.environment}-dms-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-dms-s3-role"
      Environment = var.environment
    }
  )
}

# IAM Policy for DMS to access S3 and KMS
resource "aws_iam_role_policy" "dms_s3_policy" {
  name = "${var.project_name}-${var.environment}-dms-s3-policy"
  role = aws_iam_role.dms_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:PutObjectTagging",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = flatten([
          for bucket in values(var.target_s3_buckets) : [
            "arn:aws:s3:::${bucket}",
            "arn:aws:s3:::${bucket}/*"
          ]
        ])
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# IAM Role for DMS VPC Management
resource "aws_iam_role" "dms_vpc_role" {
  name = "${var.project_name}-${var.environment}-dms-vpc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-dms-vpc-role"
      Environment = var.environment
    }
  )
}

# Attach AWS managed policy for DMS VPC management
resource "aws_iam_role_policy_attachment" "dms_vpc_policy" {
  role       = aws_iam_role.dms_vpc_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

# IAM Role for CloudWatch Logs
resource "aws_iam_role" "dms_cloudwatch_role" {
  name = "${var.project_name}-${var.environment}-dms-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-dms-cloudwatch-role"
      Environment = var.environment
    }
  )
}

# Attach AWS managed policy for CloudWatch Logs
resource "aws_iam_role_policy_attachment" "dms_cloudwatch_policy" {
  role       = aws_iam_role.dms_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
}

# Replication Tasks
resource "aws_dms_replication_task" "tasks" {
  for_each = { for task in var.replication_tasks : task.task_id => task }

  replication_task_id       = "${var.project_name}-${var.environment}-${each.value.task_id}"
  migration_type            = each.value.migration_type
  replication_instance_arn  = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn       = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn       = aws_dms_endpoint.target[each.value.target_bucket].endpoint_arn
  table_mappings            = each.value.table_mappings

  replication_task_settings = jsonencode({
    TargetMetadata = {
      TargetSchema = ""
      SupportLobs  = true
      FullLobMode  = false
      LobChunkSize = 64
      LimitedSizeLobMode = true
      LobMaxSize   = 32
    }
    FullLoadSettings = {
      TargetTablePrepMode = "DO_NOTHING"
      CreatePkAfterFullLoad = false
      StopTaskCachedChangesApplied = false
      StopTaskCachedChangesNotApplied = false
      MaxFullLoadSubTasks = 8
      TransactionConsistencyTimeout = 600
      CommitRate = 10000
    }
    Logging = {
      EnableLogging = true
      LogComponents = [
        {
          Id       = "TRANSFORMATION"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "SOURCE_UNLOAD"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "IO"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "TARGET_LOAD"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "PERFORMANCE"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "SOURCE_CAPTURE"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "SORTER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "REST_SERVER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "VALIDATOR_EXT"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "TARGET_APPLY"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "TASK_MANAGER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "TABLES_MANAGER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "METADATA_MANAGER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "FILE_FACTORY"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "COMMON"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "ADDONS"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "DATA_STRUCTURE"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "COMMUNICATION"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "FILE_TRANSFER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        }
      ]
    }
    ChangeProcessingDdlHandlingPolicy = {
      HandleSourceTableDropped   = true
      HandleSourceTableTruncated = true
      HandleSourceTableAltered   = true
    }
    ErrorBehavior = {
      DataErrorPolicy                 = "LOG_ERROR"
      EventErrorPolicy                = "IGNORE"
      DataTruncationErrorPolicy       = "LOG_ERROR"
      DataErrorEscalationPolicy       = "SUSPEND_TABLE"
      DataErrorEscalationCount        = 50
      TableErrorPolicy                = "SUSPEND_TABLE"
      TableErrorEscalationPolicy      = "STOP_TASK"
      TableErrorEscalationCount       = 50
      RecoverableErrorCount           = -1
      RecoverableErrorInterval        = 5
      RecoverableErrorThrottling      = true
      RecoverableErrorThrottlingMax   = 1800
      RecoverableErrorStopRetryAfterThrottlingMax = false
      ApplyErrorDeletePolicy          = "IGNORE_RECORD"
      ApplyErrorInsertPolicy          = "LOG_ERROR"
      ApplyErrorUpdatePolicy          = "LOG_ERROR"
      ApplyErrorEscalationPolicy      = "LOG_ERROR"
      ApplyErrorEscalationCount       = 0
      ApplyErrorFailOnTruncationDdl   = false
      FullLoadIgnoreConflicts         = true
    }
    ChangeProcessingTuning = {
      BatchApplyPreserveTransaction  = true
      BatchApplyTimeoutMin           = 1
      BatchApplyTimeoutMax           = 30
      BatchApplyMemoryLimit          = 500
      BatchSplitSize                 = 0
      MinTransactionSize             = 1000
      CommitTimeout                  = 1
      MemoryLimitTotal               = 1024
      MemoryKeepTime                 = 60
      StatementCacheSize             = 50
    }
    ValidationSettings = {
      EnableValidation                 = true
      ValidationMode                   = "ROW_LEVEL"
      ThreadCount                      = 5
      FailureMaxCount                  = 10000
      RecordFailureDelayInMinutes      = 5
      RecordSuspendDelayInMinutes      = 30
      MaxKeyColumnSize                 = 8096
      TableFailureMaxCount             = 1000
      ValidationOnly                   = false
      HandleCollationDiff              = false
      RecordFailureDelayLimitInMinutes = 0
      SkipLobColumns                   = false
      ValidationPartialLobSize         = 0
      ValidationQueryCdcDelaySeconds   = 0
    }
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-${each.value.task_id}"
      Environment = var.environment
      System      = each.value.target_bucket
    }
  )

  depends_on = [
    aws_dms_replication_instance.main,
    aws_dms_endpoint.source,
    aws_dms_endpoint.target
  ]
}

# CloudWatch Log Group for DMS
resource "aws_cloudwatch_log_group" "dms_logs" {
  name              = "/aws/dms/${var.project_name}-${var.environment}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-dms-logs"
      Environment = var.environment
    }
  )
}
