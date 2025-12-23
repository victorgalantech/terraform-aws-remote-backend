variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name (dev, qa, pro)"
  type        = string
  validation {
    condition     = contains(["dev", "qa", "pro"], var.environment)
    error_message = "Environment must be one of: dev, qa, pro"
  }
}

variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state (must be globally unique). Must be provided via GitHub Variables as TERRAFORM_STATE_BUCKET_NAME."
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking. If not provided, will be generated as terraform-state-locks-{environment}"
  type        = string
  default     = ""
}

variable "noncurrent_version_expiration_days" {
  description = "Number of days to retain noncurrent versions of state files"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "Terraform-State-Management"
    Environment = "shared"
    ManagedBy   = "Terraform"
  }
}
