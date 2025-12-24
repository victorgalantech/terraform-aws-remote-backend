# Backend Configuration for QA Environment
#
# This file configures where Terraform stores the state for THIS Terraform
# (the infrastructure that creates state backends for other projects).
#
# Usage:
#   terraform init -backend-config=backend-qa.hcl
#
# Before first use, create the backend with:
#   ./scripts/setup-environment.sh qa bootstrap

bucket         = "victorgalantech-tfstate-qa"
key            = "backend-infrastructure/terraform.tfstate"
region         = "eu-west-1"
dynamodb_table = "terraform-state-locks"
encrypt        = true
