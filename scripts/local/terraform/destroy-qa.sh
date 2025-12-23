#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_DIR="$SCRIPT_DIR"
REPO_ROOT=""
for _ in 1 2 3 4 5 6; do
    if [ -d "$CURRENT_DIR/terraform" ]; then
        REPO_ROOT="$CURRENT_DIR"
        break
    fi
    CURRENT_DIR="$(dirname "$CURRENT_DIR")"
done

if [ -z "$REPO_ROOT" ]; then
    echo "ERROR: terraform directory not found relative to $SCRIPT_DIR"
    exit 1
fi

TERRAFORM_DIR="$REPO_ROOT/terraform"
TFVARS_FILE="qa.tfvars"

echo "========================================"
echo "Terraform Destroy - QA Environment"
echo "========================================"
echo ""

if [ ! -f "$TERRAFORM_DIR/$TFVARS_FILE" ]; then
    echo "ERROR: $TFVARS_FILE not found in $TERRAFORM_DIR"
    echo "Please create the file from terraform.tfvars.example"
    exit 1
fi

cd "$TERRAFORM_DIR"

echo "Step 1: Initializing Terraform..."
terraform init

echo ""
echo "Step 2: Planning destruction..."
terraform plan -destroy -var-file="$TFVARS_FILE" -out=tfplan-destroy-qa

echo ""
echo "========================================"
echo "WARNING: DESTRUCTIVE OPERATION"
echo "========================================"
echo "This will DESTROY all resources in QA environment:"
echo "  - S3 bucket for Terraform state"
echo "  - DynamoDB table for state locking"
echo "  - All associated configurations"
echo ""
read -p "Type 'destroy-qa' to confirm destruction: " confirmation

if [ "$confirmation" = "destroy-qa" ]; then
    terraform apply tfplan-destroy-qa
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "========================================"
        echo "SUCCESS: QA environment destroyed!"
        echo "========================================"
        
        rm -f tfplan-destroy-qa
    else
        echo "ERROR: Terraform destroy failed"
        exit 1
    fi
else
    echo "Destroy cancelled - confirmation did not match"
    rm -f tfplan-destroy-qa
    exit 0
fi
