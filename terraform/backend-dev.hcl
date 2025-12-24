# Backend Configuration for DEV Environment
#
# This file configures where Terraform stores the state for THIS Terraform
# (the infrastructure that creates state backends for other projects).
#
# Usage:
#   terraform init -backend-config=backend-dev.hcl
#
# Before first use, create the backend with:
#   ./scripts/setup-environment.sh dev bootstrap

bucket         = "victorgalantech-tfstate-dev"
key            = "backend-infrastructure/terraform.tfstate"
region         = "eu-west-1"
dynamodb_table = "terraform-state-locks"
encrypt        = true
