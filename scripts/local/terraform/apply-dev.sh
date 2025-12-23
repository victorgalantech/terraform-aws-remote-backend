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
TFVARS_FILE="dev.tfvars"

echo "========================================"
echo "Terraform Apply - DEV Environment"
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
echo "Step 2: Validating configuration..."
terraform validate

echo ""
echo "Step 3: Planning changes..."
terraform plan -var-file="$TFVARS_FILE" -out=tfplan-dev

echo ""
echo "Step 4: Applying changes..."
echo "WARNING: This will create resources in AWS DEV environment"
read -p "Do you want to proceed? (yes/no): " confirmation

if [ "$confirmation" = "yes" ]; then
    terraform apply tfplan-dev
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "========================================"
        echo "SUCCESS: DEV environment deployed!"
        echo "========================================"
        
        rm -f tfplan-dev
    else
        echo "ERROR: Terraform apply failed"
        exit 1
    fi
else
    echo "Apply cancelled by user"
    rm -f tfplan-dev
    exit 0
fi
