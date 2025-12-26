# Backend Setup Guide

## The Inception Problem

This Terraform repository creates S3 buckets and DynamoDB tables for **storing Terraform state**. But where does **this Terraform** store its own state?

**The Paradox:**
- Terraform needs remote state storage to track infrastructure
- This repository creates that storage infrastructure  
- GitHub Actions runners are ephemeral (state would be lost)
- We can't use the bucket we're creating to store the state that creates it... or can we?

**The Solution:** Use Terraform's state migration feature to bootstrap elegantly.

---

## 🎯 Recommended Approach: Backend Migration

This is the **cleanest and most maintainable** approach. It uses pure Terraform with native state migration.

### How It Works

1. **Deploy locally** with local state (creates S3 + DynamoDB)
2. **Migrate state** to the remote backend you just created
3. **GitHub Actions** uses remote state automatically

### Complete Workflow

#### Step 1: Generate Configuration Files

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

#### Step 2: Deploy Backend Infrastructure (Per Environment)

**For DEV environment:**

```bash
cd terraform

# Initialize with local backend (backend block is commented out by default)
terraform init

# Deploy infrastructure - state stored locally
terraform apply -var-file=dev.tfvars
```

**What gets created:**
- ✅ S3 bucket: `victorgalantech-tfstate-dev`
- ✅ DynamoDB table: `terraform-state-locks` (same name in each AWS account)
- ✅ State stored: **locally** in `terraform.tfstate`

**Verify:**
```bash
aws s3 ls | grep victorgalantech-tfstate-dev
aws dynamodb list-tables | grep terraform-state-locks
```

---

#### Step 3: Migrate State to Remote Backend

**3.1 Uncomment backend block**

Edit `terraform/backend.tf` and uncomment the backend configuration (lines 47-51):

**Before:**
```hcl
terraform {
  # UNCOMMENT THIS BLOCK AFTER FIRST DEPLOYMENT
  # backend "s3" {
  #   # Configuration provided via backend-{env}.hcl files
  # }
}
```

**After:**
```hcl
terraform {
  backend "s3" {
    # Configuration provided via backend-{env}.hcl files
  }
}
```

**3.2 Run migration**

```bash
terraform init -backend-config=backend-dev.hcl -migrate-state
```

**Interactive prompt:**
```
Initializing the backend...
Terraform has detected you're configuring a new backend.
Do you want to copy existing state to the new backend?

Enter a value: yes    ← Type 'yes' and press Enter
```

**Result:**
- ✅ Local `terraform.tfstate` uploaded to S3: `s3://victorgalantech-tfstate-dev/backend-infrastructure/terraform.tfstate`
- ✅ Future operations use remote backend automatically
- ✅ State locking via DynamoDB enabled

**3.3 Verify migration**

```bash
# Should show "No changes" - state was migrated correctly
terraform plan -var-file=dev.tfvars

# Check S3 bucket contains state
aws s3 ls s3://victorgalantech-tfstate-dev/backend-infrastructure/
```

**Expected output:**
```
2024-12-24 12:00:00       1234 terraform.tfstate
```

---

#### Step 4: Repeat for QA and PRO Environments

```bash
# QA Environment
terraform apply -var-file=qa.tfvars
# (Uncomment backend block if you commented it back)
terraform init -backend-config=backend-qa.hcl -migrate-state

# PRO Environment  
terraform apply -var-file=pro.tfvars
terraform init -backend-config=backend-pro.hcl -migrate-state
```

**Note:** You only need to uncomment the backend block once. After that, it stays uncommented for all environments.

---

#### Step 5: Configure GitHub Actions

Set up repository secrets and variables:

**Secrets** (Repository → Settings → Secrets and variables → Actions):
```yaml
AWS_ACCESS_KEY_ID: <your-access-key>
AWS_SECRET_ACCESS_KEY: <your-secret-key>
```

**Variables** (Repository → Settings → Secrets and variables → Actions → Variables):
```yaml
TF_STATE_BUCKET_NAME: victorgalantech-tfstate
TF_LOCK_DYNAMODB_TABLE_NAME: terraform-state-locks
```

**Important:** Don't include environment suffix - the workflow adds it automatically.

---

#### Step 6: Push and Deploy

```bash
git add .
git commit -m "Configure remote state backends"
git push origin develop     # Deploys to DEV
```

✅ **GitHub Actions will:**
1. Detect environment from branch
2. Initialize with remote backend: `terraform init -backend-config=backend-dev.hcl`
3. Run plan and apply using the remote state you created
4. Everything works automatically!

---

## ⚠️ Important: The Inception Risk

After migration, you have **self-referential infrastructure**:
- Terraform manages the S3 bucket
- That S3 bucket stores Terraform's state

### What Could Go Wrong?

If you run `terraform destroy`, Terraform will:
1. Read state from S3 to know what to destroy
2. Destroy the S3 bucket
3. Try to write final state... to the bucket it just deleted ❌

Result: **Zombie state** - resources partially deleted, state lost.

### Safety Measures (Already Implemented)

#### 1. Lifecycle Protection

`terraform/main.tf` includes:
```hcl
resource "aws_s3_bucket" "terraform_state" {
  lifecycle {
    prevent_destroy = true  # ✅ Blocks accidental deletion
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  lifecycle {
    prevent_destroy = true  # ✅ Blocks accidental deletion
  }
}
```

#### 2. Never Run Full Destroy

**❌ NEVER DO THIS:**
```bash
terraform destroy  # Dangerous!
```

**✅ Use targeted destroys instead:**
```bash
terraform destroy -target=aws_resource.specific_resource
```

#### 3. If You Must Delete Everything

```bash
# 1. Export state backup
terraform state pull > backup-state-$(date +%Y%m%d).json

# 2. Remove backend resources from Terraform management
terraform state rm aws_s3_bucket.terraform_state
terraform state rm aws_s3_bucket_versioning.terraform_state
terraform state rm aws_s3_bucket_server_side_encryption_configuration.terraform_state
terraform state rm aws_s3_bucket_public_access_block.terraform_state
terraform state rm aws_s3_bucket_lifecycle_configuration.terraform_state
terraform state rm aws_dynamodb_table.terraform_locks

# 3. Destroy other resources
terraform destroy -var-file=dev.tfvars

# 4. Manually delete bucket and table
aws s3 rb s3://victorgalantech-tfstate-dev --force
aws dynamodb delete-table --table-name terraform-state-locks
```

---

## 🔧 Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                   AWS Account A (DEV)                        │
│                                                              │
│  • S3: victorgalantech-tfstate-dev                          │
│  • DynamoDB: terraform-state-locks                          │
│                                                              │
│  Stores:                                                     │
│  1. THIS Terraform's state (backend-infrastructure/)        │
│  2. OTHER dev projects' state (project-name/)               │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                   AWS Account B (QA)                         │
│                                                              │
│  • S3: victorgalantech-tfstate-qa                           │
│  • DynamoDB: terraform-state-locks                          │
│                                                              │
│  Stores: Same pattern as DEV                                │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                   AWS Account C (PRO)                        │
│                                                              │
│  • S3: victorgalantech-tfstate-pro                          │
│  • DynamoDB: terraform-state-locks                          │
│                                                              │
│  Stores: Same pattern as DEV                                │
└──────────────────────────────────────────────────────────────┘
```

**Key Points:**
- **Multi-Account Architecture**: Each environment uses a separate AWS account
- **3 S3 buckets**: One per environment (dev, qa, pro) with environment suffix
- **3 DynamoDB tables**: Same name `terraform-state-locks` in each AWS account (no suffix needed)
- Complete environment isolation at the AWS account level
- Each environment's Terraform state stored in its own bucket in its own account

---

## 🔄 Alternative: Manual Bootstrap (AWS CLI)

For users who prefer not to use the migration approach or need maximum safety:

### Prerequisites
- AWS CLI configured
- Permissions to create S3 buckets and DynamoDB tables

### Create S3 Bucket (Per Environment)

```bash
# DEV bucket
aws s3api create-bucket \
  --bucket victorgalantech-tfstate-dev \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket victorgalantech-tfstate-dev \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket victorgalantech-tfstate-dev \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket victorgalantech-tfstate-dev \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Repeat for QA and PRO with different bucket names
```

### Create DynamoDB Table (Per AWS Account)

```bash
# Create the lock table (same name in each AWS account)
aws dynamodb create-table \
  --table-name terraform-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-west-1

# Enable point-in-time recovery
aws dynamodb update-continuous-backups \
  --table-name terraform-state-locks \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true
```

### Then Use Terraform Normally

```bash
cd terraform

# Backend block should be UNCOMMENTED from the start
terraform init -backend-config=backend-dev.hcl
terraform apply -var-file=dev.tfvars
```

**Pros:**
- ✅ No inception risk
- ✅ Backend not managed by Terraform

**Cons:**
- ❌ Mixed approach (CLI + Terraform)
- ❌ Future S3/DynamoDB changes require AWS CLI commands
- ❌ Not pure Infrastructure as Code

---

## 📊 Comparison Table

| Aspect | Backend Migration (Recommended) | Manual Bootstrap (AWS CLI) |
|--------|--------------------------------|----------------------------|
| **Simplicity** | ✅ Single workflow | ❌ Two-step process |
| **Pure IaC** | ✅ Everything in Terraform code | ⚠️ Mixed (CLI + Terraform) |
| **Future Changes** | ✅ Update Terraform code | ❌ Manual CLI commands |
| **Inception Risk** | ⚠️ Yes (mitigated by lifecycle) | ✅ No risk |
| **Accidental Destroy** | ⚠️ Possible (prevented) | ✅ Not managed |
| **Recommended For** | Most use cases | Maximum safety requirements |

---

## 🛠️ Troubleshooting

### Error: "Backend configuration changed"

```bash
terraform init -reconfigure -backend-config=backend-dev.hcl
```

### Error: DynamoDB table name mismatch

**Issue:** Local scripts or tfvars have wrong table name.

**Fix:** Ensure `TF_LOCK_DYNAMODB_TABLE_NAME = "terraform-state-locks"` (no environment suffix)

Check these files:
- `terraform/dev.tfvars`
- `terraform/qa.tfvars`
- `terraform/pro.tfvars`
- `terraform/backend-dev.hcl` (should have `dynamodb_table = "terraform-state-locks"`)

### Lost Local State Before Migration

```bash
# Import existing resources
terraform import aws_s3_bucket.terraform_state victorgalantech-tfstate-dev
terraform import aws_dynamodb_table.terraform_locks terraform-state-locks

# Then migrate
terraform init -backend-config=backend-dev.hcl -migrate-state
```

### State Drift After Migration

```bash
# Refresh state
terraform refresh -var-file=dev.tfvars

# Verify no changes
terraform plan -var-file=dev.tfvars
```

---

## 💰 Cost Estimate

Per-environment backends are **minimal cost**:

- **S3 Buckets** (3 total): ~$0.023/GB/month × 3 environments
  - You'll use <1MB per environment = **~$0.07/month total**
- **DynamoDB Table** (1 shared): Pay-per-request
  - ~$0.00001 per read/write operation
  - Expected: <100 operations/day = **~$0.03/month**
- **Data Transfer**: State files are small, negligible cost

**Total expected cost: < $0.10 USD/month**

---

## 🔒 Security Best Practices

1. **Encryption at rest**: AES256 encryption enabled on all buckets
2. **Versioning enabled**: Can recover from corrupted state
3. **Public access blocked**: Buckets are private
4. **State locking**: DynamoDB prevents concurrent modifications
5. **IAM policies**: Restrict access to GitHub Actions role only
6. **No state in Git**: State files never committed to repository

---

## 📚 Next Steps

After completing setup:

1. ✅ All environment backends created (dev, qa, pro)
2. ✅ State migrated to remote S3
3. ✅ GitHub Actions configured
4. Configure other Terraform projects to use these backends (see [README.md](README.md#-usage-in-other-projects))
5. Monitor state changes in S3 console
6. Review GitHub Actions workflow runs

---

## 📖 Quick Reference

### Complete Setup (One Environment)

```bash
# 1. Generate config
./scripts/setup-environment.sh dev

# 2. Deploy locally
cd terraform
terraform init
terraform apply -var-file=dev.tfvars

# 3. Uncomment backend block in backend.tf

# 4. Migrate to remote
terraform init -backend-config=backend-dev.hcl -migrate-state

# 5. Verify
terraform plan -var-file=dev.tfvars  # Should show "No changes"

# Done! ✅
```

### Safety Commands

```bash
# Export state backup
terraform state pull > state-backup-$(date +%Y%m%d).json

# View state location
cat .terraform/terraform.tfstate | grep bucket

# List managed resources
terraform state list
```

---

## ❓ FAQ

**Q: Why use the same DynamoDB table name across AWS accounts?**  
A: With multi-account architecture, each AWS account has its own `terraform-state-locks` table. Using the same name simplifies configuration and scripts. Since each table is in a separate AWS account, there's no conflict.

**Q: Can I use different bucket names?**  
A: Yes! Update the base name in `scripts/setup-environment.sh` or `setup-environment.ps1` before generating tfvars.

**Q: What if bucket name is already taken?**  
A: S3 bucket names must be globally unique. Choose a different base name that includes your organization or project identifier.

**Q: Should I use migration approach for production?**  
A: Yes, with caution. The lifecycle protection prevents accidental deletion. For maximum safety, consider the manual bootstrap approach.

**Q: How do I add more environments?**  
A: Create new tfvars (`staging.tfvars`), new backend config (`backend-staging.hcl`), and repeat the migration workflow.
