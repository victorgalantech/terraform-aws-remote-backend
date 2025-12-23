#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Destroy Terraform resources for DEV environment
.DESCRIPTION
    Destroys all Terraform-managed resources in the dev environment
.EXAMPLE
    .\destroy-dev.ps1
#>

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$CURRENT_DIR = $SCRIPT_DIR
$TERRAFORM_DIR = $null
for ($i = 0; $i -lt 7; $i++) {
    $candidate = Join-Path $CURRENT_DIR "terraform"
    if (Test-Path $candidate) {
        $TERRAFORM_DIR = $candidate
        break
    }
    $parent = Split-Path -Parent $CURRENT_DIR
    if ($parent -eq $CURRENT_DIR) { break }
    $CURRENT_DIR = $parent
}

if (-not $TERRAFORM_DIR) {
    Write-Host "ERROR: terraform directory not found relative to $SCRIPT_DIR" -ForegroundColor Red
    exit 1
}
$TFVARS_FILE = "dev.tfvars"

Write-Host "========================================" -ForegroundColor Red
Write-Host "Terraform Destroy - DEV Environment" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""

if (-not (Test-Path (Join-Path $TERRAFORM_DIR $TFVARS_FILE))) {
    Write-Host "ERROR: $TFVARS_FILE not found in $TERRAFORM_DIR" -ForegroundColor Red
    Write-Host "Please create the file from terraform.tfvars.example" -ForegroundColor Yellow
    exit 1
}

Set-Location $TERRAFORM_DIR

Write-Host "Step 1: Initializing Terraform..." -ForegroundColor Green
terraform init

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform init failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 2: Planning destruction..." -ForegroundColor Yellow
terraform plan -destroy -var-file=$TFVARS_FILE -out=tfplan-destroy-dev

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform plan failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Red
Write-Host "WARNING: DESTRUCTIVE OPERATION" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host "This will DESTROY all resources in DEV environment:" -ForegroundColor Yellow
Write-Host "  - S3 bucket for Terraform state" -ForegroundColor Yellow
Write-Host "  - DynamoDB table for state locking" -ForegroundColor Yellow
Write-Host "  - All associated configurations" -ForegroundColor Yellow
Write-Host ""
Write-Host "Type 'destroy-dev' to confirm destruction:" -ForegroundColor Red
$confirmation = Read-Host

if ($confirmation -eq "destroy-dev") {
    terraform apply tfplan-destroy-dev
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "SUCCESS: DEV environment destroyed!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        
        Remove-Item tfplan-destroy-dev -ErrorAction SilentlyContinue
    } else {
        Write-Host "ERROR: Terraform destroy failed" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Destroy cancelled - confirmation did not match" -ForegroundColor Yellow
    Remove-Item tfplan-destroy-dev -ErrorAction SilentlyContinue
    exit 0
}
