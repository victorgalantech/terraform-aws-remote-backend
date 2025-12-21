# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Environment-based workflow** with branch-to-environment mapping:
  - `feature/*` and `develop` → dev environment
  - `release/*` → qa environment
  - `main` → pro environment
- Dynamic S3 bucket naming based on environment (`victorgalantech-tfstate-{env}`)
- Environment validation (must be dev, qa, or pro)
- Automatic environment detection in CI/CD pipeline
- Environment-specific tags on all resources
- Organized Terraform files into `terraform/` folder

### Changed
- Updated CI/CD workflow to support multiple environments
- Modified variables to include required `environment` parameter
- Enhanced README with environment workflow documentation

## [1.0.0] - 2025-12-21

### Added
- **S3 Bucket** for Terraform state storage with:
  - Versioning enabled for disaster recovery
  - AES256 server-side encryption
  - Public access blocked
  - Lifecycle policies for old version cleanup
  - TLS enforcement via bucket policy
  - `prevent_destroy` lifecycle rule to avoid accidental deletion

- **DynamoDB Table** for state locking:
  - Pay-per-request billing mode
  - `prevent_destroy` lifecycle rule
  - LockID hash key for concurrent access control

- **Infrastructure as Code**:
  - `main.tf` - Core infrastructure resources
  - `variables.tf` - Configurable parameters
  - `outputs.tf` - Backend configuration outputs
  - `terraform.tfvars.example` - Example configuration

- **CI/CD Pipeline**:
  - Automated Terraform validation and planning
  - Automatic apply on main/develop branches
  - Pull request comments with plan output
  - Security scanning with Checkov and tfsec
  - Artifact upload/download for plan files

- **Documentation**:
  - Comprehensive README with usage instructions
  - Example backend configurations
  - Security best practices

### Security
- Enforced TLS/HTTPS for all S3 operations
- Blocked all public access to S3 bucket
- Enabled encryption at rest (AES256)
- State locking to prevent concurrent modifications

### Configuration
- Default region: `eu-west-1`
- Default bucket name: `template-lambda-tfstate-victor`
- Noncurrent version retention: 90 days
- Incomplete multipart upload cleanup: 7 days

---

## How to Update This Changelog

When making changes, add entries under `[Unreleased]` in the appropriate category:

### Categories
- **Added** - New features
- **Changed** - Changes in existing functionality
- **Deprecated** - Soon-to-be removed features
- **Removed** - Removed features
- **Fixed** - Bug fixes
- **Security** - Security improvements

### Example Entry Format
```markdown
## [Unreleased]

### Added
- New feature description (#PR-number)

### Fixed
- Bug fix description (#PR-number)
```

When releasing a new version:
1. Move `[Unreleased]` items to a new version section
2. Add the release date
3. Update version numbers following semantic versioning
4. Create a new empty `[Unreleased]` section
