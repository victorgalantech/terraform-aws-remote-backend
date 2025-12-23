#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Apply Terraform configuration for DEV environment
.DESCRIPTION
    Initializes and applies Terraform configuration for the dev environment
.EXAMPLE
    .\apply-dev.ps1
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

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Terraform Apply - DEV Environment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
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
Write-Host "Step 2: Validating configuration..." -ForegroundColor Green
terraform validate

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform validation failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 3: Planning changes..." -ForegroundColor Green
terraform plan -var-file=$TFVARS_FILE -out=tfplan-dev

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform plan failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 4: Applying changes..." -ForegroundColor Green
Write-Host "WARNING: This will create resources in AWS DEV environment" -ForegroundColor Yellow
$confirmation = Read-Host "Do you want to proceed? (yes/no)"

if ($confirmation -eq "yes") {
    terraform apply tfplan-dev
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "SUCCESS: DEV environment deployed!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        
        Remove-Item tfplan-dev -ErrorAction SilentlyContinue
    } else {
        Write-Host "ERROR: Terraform apply failed" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Apply cancelled by user" -ForegroundColor Yellow
    Remove-Item tfplan-dev -ErrorAction SilentlyContinue
    exit 0
}
