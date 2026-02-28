# First Deploy — CLI Wizard Guide

Interactive bash script that provisions the complete AWS stack for the digi-dan oss community join site.

## Quick Start

```bash
# From WSL or Git Bash:
bash deploy.sh
```

The wizard is **safe to re-run** — it detects existing resources and skips/updates them.

---

## Prerequisites

| Tool | Install | Used For |
|------|---------|----------|
| AWS CLI v2 | `winget install Amazon.AWSCLI` | All AWS operations |
| Terraform >= 1.6 | `winget install Hashicorp.Terraform` | Infrastructure provisioning |
| Git | Already installed (you cloned this repo) | Version control |
| sed | Comes with WSL/Git Bash | Inject API URL into HTML |
| gh CLI (optional) | `winget install GitHub.cli` | Auto-set GitHub Actions secrets |

### AWS Account Setup (before running the script)

1. **Create an IAM user** named `digi-dan-deployer` with these policies:
   - `AmazonS3FullAccess`
   - `AmazonDynamoDBFullAccess`
   - `AWSLambda_FullAccess`
   - `AmazonAPIGatewayAdministrator`
   - `CloudFrontFullAccess`
   - `AmazonSESFullAccess`
   - `IAMFullAccess`
   - `CloudWatchLogsFullAccess`

2. **Generate access keys** for the user (CLI type)

3. **Configure AWS CLI**:
   ```bash
   aws configure
   # Access Key ID:     AKIA...
   # Secret Access Key: ...
   # Region:            il-central-1
   # Output:            json
   ```

> The script **never reads, stores, or manages secrets**. AWS credentials must be configured via `aws configure` before running.

---

## What the Script Does

### Step 1: Check Prerequisites
- Verifies `aws`, `terraform`, `git`, `sed` are installed
- Validates project files exist (`index.html`, `logo.png`, terraform configs, lambda code)
- **Fails fast** if anything is missing

### Step 2: Verify AWS Credentials
- Runs `aws sts get-caller-identity` to confirm authentication
- Displays account ID and IAM user ARN
- Checks the configured default region matches `il-central-1`

### Step 3: Scan Existing Resources
- Checks if each resource already exists in AWS:
  - S3 bucket (`digi-dan-oss-join-site`)
  - DynamoDB table (`community-applications`)
  - Lambda function (`digi-dan-oss-join-apply`)
  - API Gateway (`digi-dan-oss-join-api`)
  - CloudFront distribution
  - TF state bucket (`digi-dan-oss-tfstate`)
  - SES verified email
- Reports what will be created vs. what already exists
- **Idempotent**: safe on second/third runs

### Step 4: Check Terraform State
- Looks for existing `.terraform/` directory and `terraform.tfstate`
- Reports resource count if state already exists
- Informs whether this is a fresh or incremental deploy

### Step 5: Terraform Init
- Runs `terraform init -input=false`
- Downloads AWS provider plugins
- Configures the backend (local by default, S3 after step 12)

### Step 6: Terraform Plan (dry-run)
- Runs `terraform plan` and saves the plan to `deploy.tfplan`
- Shows exactly what will be created/changed/destroyed
- **Pauses for user confirmation** before applying

### Step 7: Terraform Apply
- Applies the saved plan (no additional prompts)
- Takes 3-5 minutes (CloudFront provisioning is slow)
- Creates:
  - S3 bucket (private, encrypted, CloudFront-only access)
  - DynamoDB table (on-demand, PITR, encrypted, GSI on email)
  - Lambda function (Node.js 20, 128MB, 10s timeout, concurrency 10)
  - IAM role for Lambda (DynamoDB PutItem + CloudWatch Logs + SES SendEmail)
  - API Gateway HTTP API (POST /apply, throttle 5/sec burst 10)
  - CloudFront distribution (Israel-only geo-restriction, HTTPS redirect, OAC)
- **On partial failure**: tells user to re-run (Terraform is idempotent)

### Step 8: Read Terraform Outputs
- Extracts from Terraform state:
  - `api_url` — API Gateway endpoint
  - `s3_bucket_name` — bucket for site files
  - `cloudfront_distribution_id` — for cache invalidation
  - `cloudfront_url` — public site URL
  - `dynamodb_table` — table name

### Step 9: Upload Site Files to S3
- Creates a temporary copy of `index.html`
- Injects the real API Gateway URL (replaces `{{API_GATEWAY_URL}}`)
- Uploads to S3 with correct content types:
  - `index.html` → `text/html; charset=utf-8`
  - `logo.png` → `image/png`
  - `logo-with-text.png` → `image/png`
- **Verifies** each file exists in S3 after upload
- Cleans up the temporary file

### Step 10: Invalidate CloudFront Cache
- Creates a `/*` invalidation to clear all cached content
- Reports the invalidation ID
- Cache clearing takes 1-2 minutes

### Step 11: Verify SES Email Identity
- Sends a verification email to `tichnundan@gmail.com`
- **Pauses**: asks user to check inbox and click the verification link
- Verifies the email was confirmed
- **Skips** if already verified on re-run
- Note: SES sandbox only sends to verified addresses (admin = sender, so this works)

### Step 12: Create Terraform Remote State Bucket
- Creates `digi-dan-oss-tfstate` bucket for shared state
- Enables versioning (protects against state corruption)
- Enables AES256 encryption
- Blocks all public access
- **Skips** if bucket already exists
- Prints instructions for migrating local state to S3

### Step 13: GitHub Actions CI/CD (Optional)
- If `gh` CLI is installed and authenticated:
  - Prompts user to paste `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
  - Sets them as GitHub repository secrets via `gh secret set`
  - **Never stores secrets** — pipes directly to `gh` CLI
- If `gh` is not available:
  - Prints manual instructions with the GitHub settings URL
- Verifies `.github/workflows/deploy.yml` exists

### Step 14: Smoke Test
- **CloudFront**: curls the site URL, expects HTTP 200 (or 403 if outside Israel)
- **API Gateway**: sends OPTIONS to `/apply`, expects HTTP 200
- **Lambda**: POSTs a test application, verifies response contains `"message"`
- **DynamoDB**: scans the table, reports item count
- Prints the test application ID for cleanup

---

## Error Recovery

| Scenario | What Happens |
|----------|-------------|
| **Missing AWS credentials** | Script aborts with setup instructions |
| **Terraform init fails** | Script aborts — usually means no internet or bad provider version |
| **Terraform apply partial failure** | Script offers to continue; re-run picks up where it left off |
| **S3 upload fails** | Reported as failure; re-run retries the upload |
| **CloudFront still deploying** | Smoke test warns; distribution takes ~5 min |
| **SES verification not clicked** | Script warns; notifications won't work until verified |
| **Second run (resources exist)** | Terraform updates in-place; uploads overwrite; SES skipped |
| **Resources from a different deploy** | Terraform may need `import` — the scan warns you |

## Modifying Constants

Edit the top of `deploy.sh` to change:

```bash
SITE_BUCKET="digi-dan-oss-join-site"    # S3 bucket name
TFSTATE_BUCKET="digi-dan-oss-tfstate"   # TF state bucket
ADMIN_EMAIL="tichnundan@gmail.com"       # SES notification target
GITHUB_REPO="mahozdan/digi-dan-oss"      # For gh CLI secret setup
```

These must match the values in `terraform/main.tf`.

---

## After Deploy

```bash
# View applications
aws dynamodb scan --table-name community-applications --region il-central-1

# Re-deploy site changes
bash deploy.sh

# Update infrastructure only
cd terraform && terraform plan && terraform apply

# Invalidate CDN cache
aws cloudfront create-invalidation --distribution-id <ID> --paths '/*'
```

## CI/CD After First Deploy

Once GitHub secrets are set, every push to `main` auto-deploys via `.github/workflows/deploy.yml`. See [DEPLOY.md](DEPLOY.md) for full CI/CD documentation.
