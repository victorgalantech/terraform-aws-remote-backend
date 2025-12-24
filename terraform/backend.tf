# Backend Configuration (Per-Environment)
#
# ⚠️ IMPORTANT: BACKEND MIGRATION APPROACH
#
# This Terraform creates S3 buckets and DynamoDB tables for state storage.
# The "inception" problem: Where does THIS Terraform store its own state?
#
# SOLUTION: Backend Migration (Local → Remote)
#
# FIRST DEPLOYMENT (Local State):
# 1. Keep this backend block COMMENTED OUT initially
# 2. Run: terraform init (local backend)
# 3. Run: terraform apply -var-file=dev.tfvars
#    → Creates S3 bucket and DynamoDB table in AWS
#    → State stored locally in terraform.tfstate file
#
# MIGRATION (Local → Remote):
# 4. UNCOMMENT the backend block below
# 5. Run: terraform init -backend-config=backend-dev.hcl -migrate-state
#    → Terraform detects local state
#    → Asks: "Copy existing state to new backend?"
#    → Answer: yes
#    → Uploads terraform.tfstate to S3 automatically
#    → Future operations use remote backend
#
# REPEAT for each environment (qa, pro) with respective backend config files.
#
# ⚠️ DANGER: THE "INCEPTION" RISK
# After migration, this Terraform manages the bucket that stores its own state.
# If you run "terraform destroy", you could delete your own state storage!
# 
# SAFETY MEASURES:
# - lifecycle { prevent_destroy = true } on S3 and DynamoDB resources
# - Always use targeted destroys: terraform destroy -target=...
# - Never run "terraform destroy" on the entire configuration
#
# See SETUP_GUIDE.md for detailed walkthrough.

terraform {
  # UNCOMMENT THIS BLOCK AFTER FIRST DEPLOYMENT
  backend "s3" {
    # Configuration provided via backend-{env}.hcl files
    # Values: bucket, key, region, dynamodb_table, encrypt
  }
}
