# S3 Data Lake Module
# Creates raw, curated, and prod buckets for a system with proper configuration

data "aws_caller_identity" "current" {}

# Raw Bucket - Receives data from DMS
resource "aws_s3_bucket" "raw" {
  bucket = "${var.system_name}-raw-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.tags,
    {
      Name        = "${var.system_name}-raw"
      Environment = var.environment
      System      = var.system_name
      BucketType  = "raw"
    }
  )
}

resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id

  versioning_configuration {
    status = "Disabled" # Raw data doesn't need versioning
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    id     = "archive-old-data"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# Enable EventBridge notifications for raw bucket
resource "aws_s3_bucket_notification" "raw" {
  bucket      = aws_s3_bucket.raw.id
  eventbridge = true
}

# Curated Bucket - Contains validated and deduplicated data
resource "aws_s3_bucket" "curated" {
  bucket = "${var.system_name}-curated-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.tags,
    {
      Name        = "${var.system_name}-curated"
      Environment = var.environment
      System      = var.system_name
      BucketType  = "curated"
    }
  )
}

resource "aws_s3_bucket_versioning" "curated" {
  bucket = aws_s3_bucket.curated.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "curated" {
  bucket = aws_s3_bucket.curated.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "curated" {
  bucket = aws_s3_bucket.curated.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "curated" {
  bucket = aws_s3_bucket.curated.id

  rule {
    id     = "archive-old-data"
    status = "Enabled"

    transition {
      days          = 180
      storage_class = "GLACIER"
    }
  }
}

# Enable EventBridge notifications for curated bucket
resource "aws_s3_bucket_notification" "curated" {
  bucket      = aws_s3_bucket.curated.id
  eventbridge = true
}

# Prod Bucket - Contains analyst-ready data
resource "aws_s3_bucket" "prod" {
  bucket = "${var.system_name}-prod-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.tags,
    {
      Name        = "${var.system_name}-prod"
      Environment = var.environment
      System      = var.system_name
      BucketType  = "prod"
    }
  )
}

resource "aws_s3_bucket_versioning" "prod" {
  bucket = aws_s3_bucket.prod.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "prod" {
  bucket = aws_s3_bucket.prod.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "prod" {
  bucket = aws_s3_bucket.prod.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "prod" {
  bucket = aws_s3_bucket.prod.id

  rule {
    id     = "intelligent-tiering"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}

# Enable EventBridge notifications for prod bucket (for Glue Crawler trigger)
resource "aws_s3_bucket_notification" "prod" {
  bucket      = aws_s3_bucket.prod.id
  eventbridge = true
}

# Bucket policies for DMS and Batch access
resource "aws_s3_bucket_policy" "raw" {
  bucket = aws_s3_bucket.raw.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowDMSWrite"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:PutObjectTagging"
        ]
        Resource = "${aws_s3_bucket.raw.arn}/*"
      },
      {
        Sid    = "AllowBatchRead"
        Effect = "Allow"
        Principal = {
          AWS = var.batch_job_role_arn
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.raw.arn,
          "${aws_s3_bucket.raw.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "curated" {
  bucket = aws_s3_bucket.curated.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBatchReadWrite"
        Effect = "Allow"
        Principal = {
          AWS = var.batch_job_role_arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.curated.arn,
          "${aws_s3_bucket.curated.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "prod" {
  bucket = aws_s3_bucket.prod.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBatchWrite"
        Effect = "Allow"
        Principal = {
          AWS = var.batch_job_role_arn
        }
        Action = [
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.prod.arn,
          "${aws_s3_bucket.prod.arn}/*"
        ]
      },
      {
        Sid    = "AllowGlueRead"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.prod.arn,
          "${aws_s3_bucket.prod.arn}/*"
        ]
      },
      {
        Sid    = "AllowAthenaRead"
        Effect = "Allow"
        Principal = {
          Service = "athena.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.prod.arn,
          "${aws_s3_bucket.prod.arn}/*"
        ]
      }
    ]
  })
}
