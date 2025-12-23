# Terraform Local Execution Scripts

This directory contains automation scripts for running Terraform locally for **dev** and **qa** environments.

## 🚨 Important Security Note

**Production environment should ONLY be deployed via CI/CD pipeline.**

These scripts are intentionally limited to dev and qa environments to prevent accidental production changes.

## 📁 Available Scripts

### PowerShell Scripts (Windows)

| Script | Description |
|--------|-------------|
| `apply-dev.ps1` | Deploy/update DEV environment |
| `apply-qa.ps1` | Deploy/update QA environment |
| `destroy-dev.ps1` | Destroy all DEV resources |
| `destroy-qa.ps1` | Destroy all QA resources |

### Bash Scripts (Linux/macOS)

| Script | Description |
|--------|-------------|
| `apply-dev.sh` | Deploy/update DEV environment |
| `apply-qa.sh` | Deploy/update QA environment |
| `destroy-dev.sh` | Destroy all DEV resources |
| `destroy-qa.sh` | Destroy all QA resources |

## 🚀 Usage

### Windows (PowerShell)

```powershell
# From the repository root
.\scripts\local\terraform\apply-dev.ps1
.\scripts\local\terraform\apply-qa.ps1
.\scripts\local\terraform\destroy-dev.ps1
.\scripts\local\terraform\destroy-qa.ps1
```

### Linux/macOS (Bash)

```bash
# Make scripts executable (first time only)
chmod +x scripts/local/terraform/*.sh

# From the repository root
./scripts/local/terraform/apply-dev.sh
./scripts/local/terraform/apply-qa.sh
./scripts/local/terraform/destroy-dev.sh
./scripts/local/terraform/destroy-qa.sh
```

## 🔄 What Each Script Does

### Apply Scripts (`apply-*.ps1` / `apply-*.sh`)

1. Checks if the required `.tfvars` file exists
2. Initializes Terraform
3. Validates the configuration
4. Creates an execution plan
5. Prompts for confirmation
6. Applies the changes if confirmed

### Destroy Scripts (`destroy-*.ps1` / `destroy-*.sh`)

1. Checks if the required `.tfvars` file exists
2. Initializes Terraform
3. Creates a destruction plan
4. Shows detailed warning about resources to be destroyed
5. Requires typing exact confirmation string (`destroy-dev` or `destroy-qa`)
6. Destroys all resources if confirmed

## ⚙️ Prerequisites

Before running these scripts, ensure:

1. **Terraform is installed** (>= 1.6.0)
   ```bash
   terraform --version
   ```

2. **AWS CLI is configured** with valid credentials
   ```bash
   aws configure
   # or ensure AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are set
   ```

3. **Environment tfvars files exist**
   - `terraform/dev.tfvars` (for dev environment)
   - `terraform/qa.tfvars` (for qa environment)

## 📝 Configuration Files

The scripts use environment-specific tfvars files located in the `terraform/` directory:

- **`terraform/dev.tfvars`** - DEV environment configuration
- **`terraform/qa.tfvars`** - QA environment configuration

These files are tracked in git and contain non-sensitive configuration values.

## 🔒 Safety Features

### Apply Scripts
- ✅ Validates configuration before applying
- ✅ Shows plan before making changes
- ✅ Requires explicit "yes" confirmation
- ✅ Cleans up plan files after execution

### Destroy Scripts
- ⚠️ Shows detailed warning about resources to be destroyed
- ⚠️ Requires typing exact environment name for confirmation
- ⚠️ Lists all resources that will be deleted
- ⚠️ Cannot be accidentally triggered

## 🐛 Troubleshooting

### Script won't run (PowerShell)

If you get an execution policy error:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Script won't run (Bash)

Make the script executable:

```bash
chmod +x scripts/apply-dev.sh
```

### tfvars file not found

Ensure the tfvars files exist in the `terraform/` directory:

```bash
ls terraform/*.tfvars
```

### AWS credentials not configured

Configure AWS CLI:

```bash
aws configure
```

Or set environment variables:

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="eu-west-1"
```

## 📊 Example Output

### Successful Apply

```
========================================
Terraform Apply - DEV Environment
========================================

Step 1: Initializing Terraform...
Terraform has been successfully initialized!

Step 2: Validating configuration...
Success! The configuration is valid.

Step 3: Planning changes...
Plan: 5 to add, 0 to change, 0 to destroy.

Step 4: Applying changes...
WARNING: This will create resources in AWS DEV environment
Do you want to proceed? (yes/no): yes

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

========================================
SUCCESS: DEV environment deployed!
========================================
```

### Successful Destroy

```
========================================
Terraform Destroy - DEV Environment
========================================

Step 1: Initializing Terraform...
Step 2: Planning destruction...

========================================
WARNING: DESTRUCTIVE OPERATION
========================================
This will DESTROY all resources in DEV environment:
  - S3 bucket for Terraform state
  - DynamoDB table for state locking
  - All associated configurations

Type 'destroy-dev' to confirm destruction: destroy-dev

Destroy complete! Resources: 5 destroyed.

========================================
SUCCESS: DEV environment destroyed!
========================================
```

## 🔗 Related Documentation

- [Main README](../../../README.md) - Project overview and full documentation
- [Terraform Variables](../../../terraform/variables.tf) - Available configuration options
- [GitHub Environments Setup](../../../GITHUB_ENVIRONMENTS_SETUP.md) - CI/CD configuration

## ⚡ Quick Reference

```bash
# Deploy dev
./scripts/local/terraform/apply-dev.sh

# Check what would be destroyed
cd terraform && terraform plan -destroy -var-file=dev.tfvars

# Destroy dev (with confirmation)
./scripts/local/terraform/destroy-dev.sh
```

---

**Remember:** Always review the plan output before confirming any changes!
