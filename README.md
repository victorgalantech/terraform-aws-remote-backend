# Terraform State S3 Bucket 🗄️

[![Terraform](https://img.shields.io/badge/Terraform-1.6+-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-S3%20%7C%20DynamoDB-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Centralized Terraform state management infrastructure using AWS S3 and DynamoDB. This repository sets up a secure, versioned S3 bucket and DynamoDB table for storing and locking Terraform state files across multiple projects.

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

| Branch Pattern | Environment | S3 Bucket Name | Auto-Deploy |
|---------------|-------------|----------------|-------------|
| `feature/*`, `develop` | **dev** | `victorgalantech-tfstate-dev` | ✅ Yes |
| `release/*` | **qa** | `victorgalantech-tfstate-qa` | ✅ Yes |
| `main` | **pro** | `victorgalantech-tfstate-pro` | ✅ Yes |

### How It Works

1. **Create a feature branch** → Automatically uses `dev` environment
2. **Merge to develop** → Deploys to `dev` environment
3. **Create release branch** (`release/v1.0.0`) → Deploys to `qa` environment
4. **Merge to main** → Deploys to `pro` environment

### Environment Isolation

Each environment gets its own:
- ✅ Dedicated S3 bucket
- ✅ Separate state files
- ✅ Independent DynamoDB lock table (shared across envs)
- ✅ Environment-specific tags

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    AWS Account                          │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  S3 Bucket: template-lambda-tfstate-victor       │  │
│  │  - Versioning: Enabled                           │  │
│  │  - Encryption: AES256                            │  │
│  │  - Public Access: Blocked                        │  │
│  │  - Lifecycle: 90 days retention                  │  │
│  └──────────────────────────────────────────────────┘  │
│                         │                               │
│                         │ State Files                   │
│                         ▼                               │
│  ┌──────────────────────────────────────────────────┐  │
│  │  DynamoDB: terraform-state-locks                 │  │
│  │  - Hash Key: LockID                              │  │
│  │  - Billing: Pay-per-request                      │  │
│  └──────────────────────────────────────────────────┘  │
│                         │                               │
│                         │ Lock Management               │
└─────────────────────────┼───────────────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │  Terraform Projects   │
              │  - template-lambda    │
              │  - other-project-1    │
              │  - other-project-2    │
              └───────────────────────┘
```

## 📦 Prerequisites

- **Terraform** >= 1.6.0
- **AWS CLI** configured with appropriate credentials
- **AWS Account** with permissions to create:
  - S3 buckets
  - DynamoDB tables
  - IAM policies (for bucket policies)

## 🚀 Quick Start

### Option A: Using Automation Scripts (Recommended for Local Development)

The easiest way to run Terraform locally for **dev** and **qa** environments:

#### Windows (PowerShell)

```powershell
# Deploy DEV environment
.\scripts\local\terraform\apply-dev.ps1

# Deploy QA environment
.\scripts\local\terraform\apply-qa.ps1

# Destroy DEV environment
.\scripts\local\terraform\destroy-dev.ps1

# Destroy QA environment
.\scripts\local\terraform\destroy-qa.ps1
```

#### Linux/macOS (Bash)

```bash
# Make scripts executable (first time only)
chmod +x scripts/local/terraform/*.sh

# Deploy DEV environment
./scripts/local/terraform/apply-dev.sh

# Deploy QA environment
./scripts/local/terraform/apply-qa.sh

# Destroy DEV environment
./scripts/local/terraform/destroy-dev.sh

# Destroy QA environment
./scripts/local/terraform/destroy-qa.sh
```

**Note:** Production environment should only be deployed via CI/CD pipeline for safety.

### Option B: Manual Terraform Commands

### 1. Clone the Repository

```bash
git clone <repository-url>
cd terraform-states-s3-bucket
```

### 2. Navigate to Terraform Directory

```bash
cd terraform
```

### 3. Configure Variables (Optional)

Copy the example file and customize:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 4. Initialize Terraform

```bash
terraform init
```

### 5. Review the Plan

Specify the environment (dev, qa, or pro):

```bash
terraform plan -var="environment=dev"
```

### 6. Apply the Configuration

```bash
terraform apply -var="environment=dev"
```

**Tip:** The CI/CD pipeline automatically sets the environment based on your branch!

### 7. Save the Outputs

```bash
terraform output backend_config_example
```

## 📝 Usage in Other Projects

After creating the state bucket, configure your other Terraform projects to use it:

### Option 1: Backend Configuration File

Create a `backend.tf` file in your project:

```hcl
terraform {
  backend "s3" {
    bucket         = "template-lambda-tfstate-victor"
    key            = "your-project/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
```

### Option 2: Backend Config During Init

```bash
terraform init \
  -backend-config="bucket=template-lambda-tfstate-victor" \
  -backend-config="key=your-project/terraform.tfstate" \
  -backend-config="region=eu-west-1" \
  -backend-config="dynamodb_table=terraform-state-locks" \
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
| `bucket_name` | S3 bucket name (auto-generated if empty) | `""` (generates `victorgalantech-tfstate-{env}`) | No |
| `dynamodb_table_name` | DynamoDB table name | `terraform-state-locks` | No |
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

# Check DynamoDB table metrics
aws dynamodb describe-table \
  --table-name terraform-state-locks \
  --query 'Table.TableSizeBytes'
```

## 🐛 Troubleshooting

### Error: Bucket Already Exists

The bucket name must be globally unique. Update `bucket_name` in `terraform.tfvars`:

```hcl
bucket_name = "your-unique-bucket-name-12345"
```

### Error: State Locked

If state is locked and the process was interrupted:

```bash
# List locks
aws dynamodb scan --table-name terraform-state-locks

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