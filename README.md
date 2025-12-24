# Terraform State S3 Bucket 🗄️

[![Terraform](https://img.shields.io/badge/Terraform-1.6+-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-S3%20%7C%20DynamoDB-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Centralized Terraform state management infrastructure using AWS S3 and DynamoDB. This repository sets up a secure, versioned S3 bucket and DynamoDB table for storing and locking Terraform state files across multiple projects.

## ⚠️ Prerequisites - Bootstrap Backend Required

**Before first use**, you must create a minimal bootstrap backend to store this Terraform's own state. This solves the "bootstrapping paradox" where we can't use the bucket we're creating to store the state that creates it.

👉 **See [SETUP_GUIDE.md](SETUP_GUIDE.md) for one-time setup instructions** (takes ~5 minutes)

## 📋 Table of Contents

- [Features](#-features)
- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Usage in Other Projects](#-usage-in-other-projects)
- [Configuration](#-configuration)
- [CI/CD Pipeline](#-cicd-pipeline)
- [Security](#-security)
- [Maintenance](#-maintenance)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)

## ✨ Features

### S3 Bucket
- ✅ **Versioning enabled** - Disaster recovery and state history
- 🔒 **Server-side encryption (AES256)** - Data encrypted at rest
- 🚫 **Public access blocked** - No public exposure
- 🔐 **TLS enforcement** - HTTPS-only access via bucket policy
- 🗑️ **Lifecycle policies** - Automatic cleanup of old versions
- 🛡️ **Prevent destroy** - Protection against accidental deletion

### DynamoDB Table
- 🔒 **State locking** - Prevents concurrent modifications
- 💰 **Pay-per-request billing** - Cost-effective for low usage
- 🛡️ **Prevent destroy** - Protection against accidental deletion

### CI/CD
- ✅ Automated validation and planning
- 🚀 Automatic deployment on main/develop branches
- 💬 PR comments with Terraform plan output
- 🔍 Security scanning (Checkov & tfsec)

## 🌍 Environment Workflow

This project implements a **branch-based environment strategy**:

| Branch Pattern | Environment | DynamoDB Table Name | Auto-Deploy |
|---------------|-------------|---------------------|-------------|
| `feature/*`, `develop` | **dev** | `terraform-state-locks-dev` | ✅ Yes |
| `release/*` | **qa** | `terraform-state-locks-qa` | ✅ Yes |
| `main` | **pro** | `terraform-state-locks-pro` | ✅ Yes |

**Note**: Both S3 bucket and DynamoDB table base names must be configured via GitHub Variables:
- `TF_STATE_BUCKET_NAME` (e.g., `victorgalantech-tfstate`)
- `TF_LOCK_DYNAMODB_TABLE_NAME` (e.g., `terraform-state-locks`)

The workflow automatically adds environment suffix (`-dev`, `-qa`, `-pro`) to both.

### How It Works

1. **Configure GitHub Variables** (both required):
   - `TF_STATE_BUCKET_NAME=victorgalantech-tfstate`
   - `TF_LOCK_DYNAMODB_TABLE_NAME=terraform-state-locks`
2. **Create a feature branch** → `dev` environment → `victorgalantech-tfstate-dev` + `terraform-state-locks-dev`
3. **Merge to develop** → Deploys to `dev`
4. **Create release branch** → `qa` environment → `victorgalantech-tfstate-qa` + `terraform-state-locks-qa`
5. **Merge to main** → `pro` environment → `victorgalantech-tfstate-pro` + `terraform-state-locks-pro`

### Environment Isolation

Each environment gets its own:
- ✅ Dedicated S3 bucket (base name from `TF_STATE_BUCKET_NAME` + environment suffix)
- ✅ Separate state files
- ✅ Independent DynamoDB lock table (base name from `TF_LOCK_DYNAMODB_TABLE_NAME` + environment suffix)
- ✅ Environment-specific tags

**Example**: Setting base names:
```
TF_STATE_BUCKET_NAME=victorgalantech-tfstate
TF_LOCK_DYNAMODB_TABLE_NAME=terraform-state-locks
```
Creates per environment:
- dev: `victorgalantech-tfstate-dev` + `terraform-state-locks-dev`
- qa: `victorgalantech-tfstate-qa` + `terraform-state-locks-qa`
- pro: `victorgalantech-tfstate-pro` + `terraform-state-locks-pro`

## 🏗️ Architecture

### Per-Environment Backend Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Account                             │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 🔧 DEV Backend (stores THIS Terraform's state for dev)  │  │
│  │                                                          │  │
│  │  S3: victorgalantech-tfstate-dev                        │  │
│  │  DynamoDB: terraform-state-locks                        │  │
│  │  Key: backend-infrastructure/terraform.tfstate          │  │
│  │                                                          │  │
│  │  Used by: terraform init -backend-config=backend-dev.hcl│  │
│  └──────────────────────────────────────────────────────────┘  │
│                              ↓                                  │
│                    (THIS Terraform manages                      │
│                     OTHER projects' backends)                   │
│                              ↓                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 📦 Application Backends for OTHER projects (dev)        │  │
│  │                                                          │  │
│  │  Same bucket/table used for:                            │  │
│  │  - Other projects' state files                          │  │
│  │  - Shared across all dev projects                       │  │
│  │                                                          │  │
│  │  Other projects use:                                    │  │
│  │    bucket = "victorgalantech-tfstate-dev"               │  │
│  │    key    = "project-name/terraform.tfstate"            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  (Same pattern repeated for QA and PRO environments)            │
└─────────────────────────────────────────────────────────────────┘
```

**Per-Environment Isolation:**
- Each environment (dev/qa/pro) has its own S3 bucket and DynamoDB table
- This Terraform's state is stored in the same bucket it manages
- Complete isolation between environments
- Each environment is bootstrapped independently

## 📦 Prerequisites

### Required
- AWS account with appropriate permissions
- Terraform 1.6 or later
- AWS CLI configured
- **Per-environment backends created** - See [SETUP_GUIDE.md](SETUP_GUIDE.md) (~10 minutes per environment)

### Optional (for CI/CD)
- GitHub account
- GitHub Actions enabled
- AWS credentials configured as GitHub Secrets

## 🚀 Quick Start

### Overview: Local Deployment → Remote State → GitHub Actions

This guide sets up **remote state backends** for all environments (dev, qa, pro) using the **Backend Migration** approach:

1. **Generate config files** for each environment
2. **Deploy locally** (creates S3 + DynamoDB infrastructure)
3. **Migrate state** from local to remote S3 backend
4. **Configure GitHub Actions** to use the remote backends
5. **Push to GitHub** - CI/CD automatically uses remote state ✅

---

### Step 1: Generate Configuration Files

Generate `tfvars` files for all three environments:

```bash
# Linux/macOS
./scripts/setup-environment.sh dev
./scripts/setup-environment.sh qa
./scripts/setup-environment.sh pro

# Windows PowerShell
.\scripts\setup-environment.ps1 dev
.\scripts\setup-environment.ps1 qa
.\scripts\setup-environment.ps1 pro
```

**Result:** Creates `terraform/dev.tfvars`, `terraform/qa.tfvars`, `terraform/pro.tfvars`

---

### Step 2: Deploy Backend Infrastructure Locally (Per Environment)

**Repeat this process for each environment (dev, qa, pro):**

#### 2.1 Initial Deployment (Local State)

```bash
cd terraform

# Initialize Terraform with LOCAL state (backend block is commented out)
terraform init

# Deploy backend infrastructure (S3 bucket + DynamoDB table)
terraform apply -var-file=dev.tfvars
```

✅ **Created:** 
- S3 bucket: `victorgalantech-tfstate-dev`
- DynamoDB table: `terraform-state-locks`
- State stored: **locally** in `terraform.tfstate`

#### 2.2 Migrate State to Remote Backend

```bash
# 1. Edit terraform/backend.tf - UNCOMMENT the backend block
#    (lines 47-51 in backend.tf)

# 2. Re-initialize with backend configuration
terraform init -backend-config=backend-dev.hcl -migrate-state

# Terraform will ask: "Do you want to copy existing state to the new backend?"
# Answer: yes
```

✅ **Result:** State now stored in S3 bucket (`terraform-backend/terraform.tfstate`)

#### 2.3 Verify Remote State

```bash
# Check that state is in S3
aws s3 ls s3://victorgalantech-tfstate-dev/terraform-backend/

# Run a plan to verify remote backend works
terraform plan -var-file=dev.tfvars
```

#### 2.4 Repeat for QA and PRO

```bash
# QA environment
terraform apply -var-file=qa.tfvars
terraform init -backend-config=backend-qa.hcl -migrate-state

# PRO environment  
terraform apply -var-file=pro.tfvars
terraform init -backend-config=backend-pro.hcl -migrate-state
```

**📖 Detailed walkthrough:** See [SETUP_GUIDE.md](SETUP_GUIDE.md)

---

### Step 3: Configure GitHub Actions

#### 3.1 Configure AWS Credentials (Secrets)

Go to: **Repository → Settings → Secrets and variables → Actions → Secrets**

Click **New repository secret** and add:

| Secret Name | Value | Description |
|------------|-------|-------------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key | AWS credentials for GitHub Actions |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key | AWS credentials for GitHub Actions |

#### 3.2 Configure Backend Names (Variables)

Go to: **Repository → Settings → Secrets and variables → Actions → Variables**

Click **New repository variable** and add:

| Variable Name | Value | Required | Notes |
|--------------|-------|----------|-------|
| `TF_STATE_BUCKET_NAME` | `victorgalantech-tfstate` | **Yes** | Base name only (no environment suffix) |
| `TF_LOCK_DYNAMODB_TABLE_NAME` | `terraform-state-locks` | **Yes** | Shared table name (no suffix) |

**Important Notes:**
- ⚠️ **Do NOT include environment suffix** - The workflow automatically adds `-dev`, `-qa`, or `-pro` based on branch
- ✅ **Must match what you created locally** in Step 2
- 🌍 **Bucket name must be globally unique** across all AWS accounts

**Example:** 
- Variable: `TF_STATE_BUCKET_NAME = victorgalantech-tfstate`
- Result:
  - dev branch → `victorgalantech-tfstate-dev`
  - qa branch → `victorgalantech-tfstate-qa`
  - main branch → `victorgalantech-tfstate-pro`

**Troubleshooting:**
- **Variables not working?** Ensure they're at repository level, not environment level
- **Wrong region?** Optionally add `AWS_REGION` variable (default: `eu-west-1`)
- **Name mismatch?** Variable values must match the backends you created in Step 2

---

### Step 4: Push and Deploy via GitHub Actions

```bash
# Commit all changes
git add .
git commit -m "Configure remote state backends"

# Push to trigger CI/CD
git push origin main        # Deploys to PRO (if configured)
git push origin develop     # Deploys to DEV
git push origin qa          # Deploys to QA
```

✅ **GitHub Actions will:**
1. Detect the environment from branch
2. Initialize Terraform with remote backend (S3)
3. Run `terraform plan` and `terraform apply`
4. Store state in the remote backend you created

---

### ✅ You're Done!

**What you have now:**
- ✅ Remote state backends for dev/qa/pro in S3
- ✅ State locking via DynamoDB
- ✅ GitHub Actions configured for CI/CD
- ✅ All future deployments use remote state automatically

**Next Steps:**
- Use these backends in other Terraform projects (see [Usage in Other Projects](#-usage-in-other-projects))
- Monitor state changes in S3
- Review GitHub Actions runs

---

## 🔄 Alternative: Using Convenience Scripts

If you prefer scripts over manual commands:

```bash
# Make scripts executable (Linux/macOS only, first time)
chmod +x scripts/*.sh

# Linux/macOS
./scripts/apply-dev.sh      # Deploy dev
./scripts/apply-qa.sh       # Deploy qa
./scripts/destroy-dev.sh    # Destroy dev

# Windows PowerShell
.\\scripts\\apply-dev.ps1
.\\scripts\\apply-qa.ps1
.\\scripts\\destroy-dev.ps1
```

**Note:** These scripts assume backend is already configured. Use manual migration workflow first.

## 📝 Usage in Other Projects

After creating the state bucket, configure your other Terraform projects to use it:

### Option 1: Backend Configuration File

Create a `backend.tf` file in your project:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-bucket-name-dev"  # From TF_STATE_BUCKET_NAME
    key            = "your-project/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-state-locks-dev"  # Auto-generated per environment
    encrypt        = true
  }
}
```

### Option 2: Backend Config During Init

```bash
terraform init \
  -backend-config="bucket=your-bucket-name-dev" \
  -backend-config="key=your-project/terraform.tfstate" \
  -backend-config="region=eu-west-1" \
  -backend-config="dynamodb_table=terraform-state-locks-dev" \
  -backend-config="encrypt=true"
```

### Migrate Existing State

If you have an existing local state:

```bash
# 1. Add backend configuration to your project
# 2. Run terraform init with -migrate-state flag
terraform init -migrate-state
```

## ⚙️ Configuration

### Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `environment` | Environment name (dev, qa, pro) | - | **Yes** |
| `aws_region` | AWS region | `eu-west-1` | No |
| `bucket_name` | S3 bucket name (full name with environment suffix) | None | **Yes** |
| `TF_LOCK_DYNAMODB_TABLE_NAME` | DynamoDB table name (full name with environment suffix) | None | **Yes** |

**GitHub Variables**: Both are required and should contain **base names only**:
- `TF_STATE_BUCKET_NAME` (e.g., `victorgalantech-tfstate`)
- `TF_LOCK_DYNAMODB_TABLE_NAME` (e.g., `terraform-state-locks`)

The workflow automatically appends `-dev`, `-qa`, or `-pro` based on the branch.
| `noncurrent_version_expiration_days` | Days to retain old versions | `90` | No |
| `tags` | Common tags for resources | See variables.tf | No |

**Note:** The `environment` variable is automatically set by CI/CD based on the branch. For manual runs, you must specify it.

### Outputs

| Output | Description |
|--------|-------------|
| `s3_bucket_id` | S3 bucket name |
| `s3_bucket_arn` | S3 bucket ARN |
| `dynamodb_table_name` | DynamoDB table name |
| `backend_config` | Backend configuration object |
| `backend_config_example` | Example backend block |

## 🔄 CI/CD Pipeline

The GitHub Actions workflow automatically:

1. **On Pull Request:**
   - Validates Terraform syntax
   - Runs security scans
   - Posts plan output as PR comment

2. **On Push to main/develop:**
   - Applies Terraform changes
   - Outputs backend configuration

### Required GitHub Environments

This project uses **GitHub Environments** for environment-specific secrets:

| Environment | Branches | Secrets Required |
|------------|----------|------------------|
| `dev` | `feature/*`, `develop` | AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION (optional) |
| `qa` | `release/*` | AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION (optional) |
| `prod` | `main` | AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION (optional) |

**📖 See [GITHUB_ENVIRONMENTS_SETUP.md](GITHUB_ENVIRONMENTS_SETUP.md) for detailed setup instructions.**

#### Quick Setup
1. Go to **Settings** → **Environments**
2. Create three environments: `dev`, `qa`, `prod`
3. Add AWS credentials to each environment (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
4. Configure protection rules (especially for `prod`)
5. **Optional:** Set `AWS_REGION` as an organization variable (defaults to `eu-west-1` if not set)

## 🔒 Security

### Best Practices Implemented

✅ **Encryption at Rest** - AES256 encryption for all state files  
✅ **Encryption in Transit** - TLS/HTTPS enforced via bucket policy  
✅ **Access Control** - Public access completely blocked  
✅ **State Locking** - Prevents concurrent modifications  
✅ **Versioning** - Enables state recovery and audit trail  
✅ **Lifecycle Prevent Destroy** - Protects against accidental deletion  

### Security Scanning

The CI/CD pipeline includes:
- **Checkov** - Infrastructure as Code security scanner
- **tfsec** - Terraform security scanner

## 🛠️ Maintenance

### Viewing State Versions

```bash
aws s3api list-object-versions \
  --bucket template-lambda-tfstate-victor \
  --prefix your-project/
```

### Restoring a Previous Version

```bash
aws s3api get-object \
  --bucket template-lambda-tfstate-victor \
  --key your-project/terraform.tfstate \
  --version-id <version-id> \
  terraform.tfstate.backup
```

### Cleaning Up Old Versions

The lifecycle policy automatically deletes versions older than 90 days. To manually clean up:

```bash
aws s3api delete-object \
  --bucket template-lambda-tfstate-victor \
  --key your-project/terraform.tfstate \
  --version-id <version-id>
```

### Monitoring Costs

```bash
# Check S3 bucket size
aws s3 ls s3://template-lambda-tfstate-victor --recursive --summarize

# Check DynamoDB table metrics (example for dev environment)
aws dynamodb describe-table \
  --table-name terraform-state-locks-dev \
  --query 'Table.TableSizeBytes'
```

## 🐛 Troubleshooting

### Error: Bucket Already Exists

The bucket name must be globally unique across all AWS accounts. Update the `TF_STATE_BUCKET_NAME` GitHub Variable:

1. Go to **Settings** > **Secrets and variables** > **Actions** > **Variables**
2. Update `TF_STATE_BUCKET_NAME` to a unique **base name** (e.g., `your-company-tfstate`)
3. Re-run the workflow (environment suffix will be added automatically)

For local runs, update `bucket_name` and `TF_LOCK_DYNAMODB_TABLE_NAME` in your `terraform.tfvars` file with the **full names** including environment suffix (e.g., `your-company-tfstate-dev`, `terraform-state-locks-dev`).

### Error: State Locked

If state is locked and the process was interrupted:

```bash
# List locks (example for dev environment)
aws dynamodb scan --table-name terraform-state-locks-dev

# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

### Error: Access Denied

Ensure your AWS credentials have the necessary permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "dynamodb:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## 📚 Additional Resources

- [Terraform S3 Backend Documentation](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [Terraform State Management](https://www.terraform.io/docs/language/state/index.html)

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Update CHANGELOG.md
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👤 Author

**Victor Galan**

---

**Note:** This infrastructure is critical for all Terraform projects. Handle with care and always review changes before applying.