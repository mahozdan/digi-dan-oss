# First Deploy: digi-dan-oss

Takes the project from "code + AWS account" to "CI/CD deploying on push to main."

## Quick Start

```bash
# Fix line endings if running from Windows → WSL
sed -i 's/\r$//' scripts/first-deploy.sh

# Run the wizard (default AWS profile: digi-dan)
bash scripts/first-deploy.sh

# Or with a different profile
bash scripts/first-deploy.sh --profile my-profile
```

The wizard is **safe to re-run** — it detects existing resources and skips/updates them.

## Prerequisites

| Requirement | Details |
|---|---|
| AWS CLI v2 | `aws --version` — [install](https://awscli.amazonaws.com/AWSCLIV2.msi) |
| Terraform >= 1.6 | `terraform --version` — `winget install Hashicorp.Terraform` |
| GitHub CLI | `gh --version` + `gh auth login` — `winget install GitHub.cli` |
| git | Remote `origin` pointing to GitHub repo |

### AWS Account Setup (before running the script)

1. **Create IAM user** `digi-dan-deployer` with access key (CLI type)

2. **Attach deploy policy** from `iam/policies/iam-policy-deploy.json`
   - Least-privilege: only the permissions needed for this project
   - Never use `*FullAccess` policies

3. **Create Lambda execution role** `digi-dan-oss-join-lambda`
   - Trust: Lambda service
   - Policy from `iam/policies/iam-lambda-permissions-policy.json`

4. **Configure AWS CLI profile**:
   ```bash
   aws configure --profile digi-dan
   # Access Key ID:     AKIA...
   # Secret Access Key: ...
   # Region:            il-central-1
   # Output:            json
   ```

> The script **never reads, stores, or manages secrets**. AWS credentials come from the CLI profile; GitHub secrets are set via `gh secret set` which handles secure input.

## What the Script Does

### Phase 1: Bootstrap

| Step | Action | Duration |
|---|---|---|
| 1/12 | Pre-flight checks (aws, terraform, gh, git, curl) | ~5s |
| 2/12 | Check IAM prerequisites (deployer policy, Lambda role) | ~10s |
| 3/12 | Create S3 state bucket with versioning | ~5s |

**Key design**: The state bucket is created via AWS CLI *before* any Terraform operation. This ensures remote state from the very first `terraform init`, avoiding orphaned resources.

### Phase 2: Infrastructure

| Step | Action | Duration |
|---|---|---|
| 4/12 | Terraform init with S3 backend | ~15s |
| 5/12 | Terraform plan + apply | ~5-10 min |
| 6/12 | Read terraform outputs | ~5s |

Creates: S3 site bucket, DynamoDB table, Lambda function, API Gateway, CloudFront distribution (Israel-only), ACM certificate, DNS records.

### Phase 3: Deploy Site

| Step | Action | Duration |
|---|---|---|
| 7/12 | Upload site files to S3 (API URL injected) | ~10s |
| 8/12 | Invalidate CloudFront cache | ~5s |
| 9/12 | Verify site responds | ~5s |

### Phase 4: Wire CI/CD

| Step | Action | Duration |
|---|---|---|
| 10/12 | Set GitHub secrets (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY) | ~30s |
| 11/12 | Push to GitHub + watch workflow run | ~3-5 min |

### Phase 5: Verification

| Step | Action | Duration |
|---|---|---|
| 12/12 | Final smoke test (site + API) | ~10s |

**Total: ~15-20 minutes**

## AWS Resources Created

| Resource | Name/ID | Region |
|---|---|---|
| S3 (state) | `digi-dan-oss-tfstate` | il-central-1 |
| S3 (site) | `digi-dan-oss-join-site` | il-central-1 |
| DynamoDB | `community-applications` | il-central-1 |
| Lambda | `digi-dan-oss-join-apply` | il-central-1 |
| API Gateway | `digi-dan-oss-join-api` | il-central-1 |
| CloudFront | distribution (Israel-only) | global |
| ACM cert | `digi-dan.com` + `www` | us-east-1 |
| Route 53 | A records + cert validation | global |

## Error Recovery

| Scenario | What Happens |
|---|---|
| Missing tools | Script aborts with install instructions |
| Permission denied | Shows the missing IAM action + policy file to update |
| S3 bucket creation denied | Manual fallback: AWS Console instructions, waits for user |
| Terraform partial failure | Safe to re-run — state tracks what was created |
| GitHub secrets already set | Prompts before overwriting |
| Resources already exist | Terraform skips/updates in-place |

## After First Deploy

- **Domain setup** (if not already done): `bash setup-domain.sh`
- **Verify SES**: Ensure sender email is verified in il-central-1
- **Test form**: Submit a test application on the live site
- **Push changes**: Every push to `main` auto-deploys via GitHub Actions

```bash
# View applications
aws dynamodb scan --table-name community-applications --region il-central-1 --profile digi-dan

# Invalidate CDN cache manually
aws cloudfront create-invalidation --distribution-id <ID> --paths '/*' --profile digi-dan
```
