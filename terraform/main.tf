terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local values
locals {
  bucket_name = var.bucket_name != "" ? var.bucket_name : "victorgalantech-tfstate-${var.environment}"
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
    }
  )
}

# 1. S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = local.bucket_name

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(
    local.common_tags,
    {
      Name      = local.bucket_name
      Purpose   = "Terraform State Storage"
      ManagedBy = "Terraform"
    }
  )
}

# 2. Enable Versioning (MANDATORY for disaster recovery)
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 3. Server-Side Encryption (Default AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# 4. Block Public Access (Security Best Practice)
resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 5. Bucket Lifecycle Policy (Optional: Clean up old versions)
resource "aws_s3_bucket_lifecycle_configuration" "state_lifecycle" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# 6. DynamoDB Table for State Locking (Prevents concurrent modifications)
resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Enable point-in-time recovery for backup
  point_in_time_recovery {
    enabled = true
  }

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(
    local.common_tags,
    {
      Name      = var.dynamodb_table_name
      Purpose   = "Terraform State Locking"
      ManagedBy = "Terraform"
    }
  )
}

# 7. S3 Bucket Policy (Optional: Restrict access to specific principals)
resource "aws_s3_bucket_policy" "terraform_state_policy" {
  bucket = aws_s3_bucket.terraform_state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforcedTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
