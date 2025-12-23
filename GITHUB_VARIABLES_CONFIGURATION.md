# GitHub Variables Configuration

This guide explains how to configure GitHub Variables for the Terraform state backend deployment.

## Why GitHub Variables?

GitHub Variables allow you to:
- Define the S3 bucket name explicitly without hardcoding in Terraform
- Use custom naming schemes per environment
- Maintain different configurations across dev/qa/pro
- Support multiple AWS accounts with different naming requirements
- Optionally override DynamoDB table naming

## Available Variables

| Variable Name | Description | Default Value | Required |
|--------------|-------------|---------------|----------|
| `TF_STATE_BUCKET_NAME` | Base S3 bucket name (environment suffix added automatically) | None | **Yes** |
| `TF_LOCK_DYNAMODB_TABLE_NAME` | Base DynamoDB table name (environment suffix added automatically) | None | **Yes** |
| `AWS_REGION` | AWS region for resources | `eu-west-1` | No |

## Naming Strategy

- **S3 Bucket**: Provide base name via `TF_STATE_BUCKET_NAME`, workflow adds `-${environment}` suffix
  - Example: `victorgalantech-tfstate` → `victorgalantech-tfstate-dev`, `victorgalantech-tfstate-qa`, `victorgalantech-tfstate-pro`
- **DynamoDB Table**: Provide base name via `TF_LOCK_DYNAMODB_TABLE_NAME`, workflow adds `-${environment}` suffix
  - Example: `terraform-state-locks` → `terraform-state-locks-dev`, `terraform-state-locks-qa`, `terraform-state-locks-pro`

## How to Configure GitHub Variables

### Step 1: Navigate to Repository Settings

1. Go to your repository on GitHub
2. Click **Settings** (top menu)
3. In the left sidebar, click **Secrets and variables** > **Actions**
4. Click the **Variables** tab

### Step 2: Add Variables

Click **New repository variable** and add:

#### Required: S3 Bucket Name (Base)

- **Name**: `TF_STATE_BUCKET_NAME`
- **Value**: `victorgalantech-tfstate` (base name only, NO environment suffix)

**Important**: 
- This variable is **required**. The workflow will fail if not set.
- Provide the **base name only** - the workflow automatically adds `-dev`, `-qa`, or `-pro` based on the branch.
- The base name must be globally unique (when combined with environment suffix).

#### Required: DynamoDB Table Name (Base)

- **Name**: `TF_LOCK_DYNAMODB_TABLE_NAME`
- **Value**: `terraform-state-locks` (base name only, NO environment suffix)

**Important**:
- This variable is **required**. The workflow will fail if not set.
- Provide the **base name only** - the workflow automatically adds `-dev`, `-qa`, or `-pro` based on the branch.

#### Optional: Different AWS Region

- **Name**: `AWS_REGION`
- **Value**: `us-east-1`

### Step 3: Environment-Specific Variables (Optional)

If you want **different values per environment** (dev/qa/pro):

1. Go to **Settings** > **Environments**
2. Create or select an environment (e.g., `dev`, `qa`, `pro`)
3. Add **Environment variables** specific to that environment
4. Update the workflow to use environment-specific contexts (advanced)

**Note**: The current workflow uses repository-level variables. For true per-environment configuration, you'd need to:
- Create GitHub Environments (dev, qa, pro)
- Add variables to each environment
- Update the workflow jobs to use `environment: ${{ steps.env.outputs.environment }}`

## Example Configurations

### Scenario 1: Repository-Level Variables (Recommended)

**Variables**:
```
TF_STATE_BUCKET_NAME=victorgalantech-tfstate
TF_LOCK_DYNAMODB_TABLE_NAME=terraform-state-locks
```

**Result**: Different resources per environment:
- dev: `victorgalantech-tfstate-dev` + `terraform-state-locks-dev`
- qa: `victorgalantech-tfstate-qa` + `terraform-state-locks-qa`
- pro: `victorgalantech-tfstate-pro` + `terraform-state-locks-pro`

✅ **Recommended**: Each environment gets its own isolated resources.

### Scenario 2: Custom Naming Convention

**Variables**:
```
TF_STATE_BUCKET_NAME=acme-corp-tfstate
TF_LOCK_DYNAMODB_TABLE_NAME=acme-corp-locks
```

**Result**:
- dev: `acme-corp-tfstate-dev` + `acme-corp-locks-dev`
- qa: `acme-corp-tfstate-qa` + `acme-corp-locks-qa`
- pro: `acme-corp-tfstate-pro` + `acme-corp-locks-pro`

### Scenario 3: Different Base Names per AWS Account (Advanced)

If using GitHub Environments with different AWS accounts:

**Environment: dev** (AWS Account A)
```
TF_STATE_BUCKET_NAME=company-dev-tfstate
TF_LOCK_DYNAMODB_TABLE_NAME=company-dev-locks
```
Result: `company-dev-tfstate-dev` + `company-dev-locks-dev`

**Environment: pro** (AWS Account B)
```
TF_STATE_BUCKET_NAME=company-prod-tfstate
TF_LOCK_DYNAMODB_TABLE_NAME=company-prod-locks
```
Result: `company-prod-tfstate-pro` + `company-prod-locks-pro`

This allows different naming schemes per AWS account while maintaining the pattern.

## Verification

After configuring variables:

1. Trigger the workflow (push to a branch)
2. Check the **Terraform Plan** step output
3. Verify the bucket/table names match your expectations

Example output:
```
Plan: 2 to add, 0 to change, 0 to destroy.

  # aws_s3_bucket.terraform_state will be created
  + resource "aws_s3_bucket" "terraform_state" {
      + bucket = "my-unique-bucket-dev"
      ...
    }

  # aws_dynamodb_table.terraform_locks will be created
  + resource "aws_dynamodb_table" "terraform_locks" {
      + name = "terraform-state-locks-dev"
      ...
    }
```

## Updating Variables

To change variables:

1. Go to **Settings** > **Secrets and variables** > **Actions** > **Variables**
2. Click **Update** next to the variable
3. Change the value and save
4. Re-run the workflow

**Important**: Changing bucket/table names after resources are created:
- Will cause Terraform to try creating **new** resources
- You'll need to either:
  - **Import** the existing resources with the new names (if you renamed them in AWS)
  - Or **keep the old names** in variables to match existing infrastructure

## Advanced: Environment-Specific Variables

To truly support different values per environment without manual switching:

### Step 1: Create GitHub Environments

1. Go to **Settings** > **Environments**
2. Create three environments: `dev`, `qa`, `pro`
3. For each environment, add protection rules as needed

### Step 2: Add Environment Variables

For each environment, add variables:
- In `dev` environment: `BUCKET_NAME=...-dev`, `TF_LOCK_DYNAMODB_TABLE_NAME=...-dev`
- In `qa` environment: `BUCKET_NAME=...-qa`, `TF_LOCK_DYNAMODB_TABLE_NAME=...-qa`
- In `pro` environment: `BUCKET_NAME=...-pro`, `TF_LOCK_DYNAMODB_TABLE_NAME=...-pro`

### Step 3: Update Workflow (requires modification)

Modify `terraform-validate` and `terraform-apply` jobs:

```yaml
jobs:
  terraform-validate:
    environment: ${{ needs.determine-env.outputs.environment }}
    # ... rest of job
```

This is more complex and requires workflow restructuring.

## Troubleshooting

### Variables Not Recognized

**Symptom**: Workflow uses defaults despite setting variables

**Solution**:
- Ensure variables are set at **repository** level (not environment level, unless workflow is configured for that)
- Variable names are case-sensitive: use exact names (`BUCKET_NAME`, not `bucket_name`)
- Re-run workflow after setting variables

### Import Required After Changing Names

**Symptom**: `BucketAlreadyOwnedByYou` or `ResourceInUseException` errors

**Solution**:
- If you changed variable names to match existing resources, you need to import them
- See [IMPORT_EXISTING_RESOURCES.md](IMPORT_EXISTING_RESOURCES.md) for import instructions

### Different Regions

**Symptom**: Resources not found or created in wrong region

**Solution**:
- Set `AWS_REGION` variable to match where you want resources
- Ensure AWS credentials (secrets) have permissions in that region
- DynamoDB table must be in the same region as the S3 bucket for backend functionality

## Best Practices

1. **Use environment suffixes**: Always include environment in names (e.g., `-dev`, `-qa`, `-pro`)
2. **Document your naming**: Keep a record of what naming scheme you're using
3. **Test in dev first**: Always test variable changes in dev environment before applying to qa/pro
4. **Avoid changing production names**: Once prod is deployed, keep names stable
5. **Use defaults when possible**: Custom names add complexity; use defaults unless required

## Questions?

Refer to:
- [Main README](README.md) - Overall project documentation
- [IMPORT_EXISTING_RESOURCES.md](IMPORT_EXISTING_RESOURCES.md) - How to import existing resources
- [GitHub Actions workflow](.github/workflows/terraform.yml) - Workflow implementation
