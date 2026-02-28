# digi-dan oss — Deployment Guide

## Architecture

```
Browser (Israel IP only)
     ↓
CloudFront (geo-restriction: IL)
     ↓
S3 (static HTML + logos)       User fills form
                                    ↓ POST /apply
                              API Gateway (HTTP API)
                                    ↓
                              Lambda (Node.js 20)
                                ├── DynamoDB (store application)
                                └── SES → tichnundan@gmail.com
```

## Cost

| Component | Monthly Cost | Free Tier |
|-----------|-------------|-----------|
| S3 | ~$0.01 | 5GB storage, 20K GET |
| API Gateway (HTTP) | ~$0 | 1M requests (12 months) |
| Lambda | ~$0 | 1M invocations |
| DynamoDB (on-demand) | ~$0 | 25GB + 25 WCU/RCU |
| CloudFront | ~$0 | 1TB transfer (12 months) |
| SES (optional) | ~$0.10 | 62K emails from Lambda |
| **Total** | **$0-1/mo** | |

---

## Step 0: AWS Account + IAM User Setup

### 0.1 Create an AWS Account (skip if you have one)

1. Go to https://aws.amazon.com and click **Create an AWS Account**
2. Follow the wizard — you need an email, credit card, and phone number
3. Select the **Free** support plan

### 0.2 Create a Dedicated IAM User

Do NOT use your root account for deployments. Create a dedicated IAM user:

1. Sign in to **AWS Console** → search for **IAM**
2. Go to **Users** → **Create user**
3. User name: `digi-dan-deployer`
4. Click **Next**
5. Select **Attach policies directly**
6. Attach these policies:
   - `AmazonS3FullAccess`
   - `AmazonDynamoDBFullAccess`
   - `AWSLambda_FullAccess`
   - `AmazonAPIGatewayAdministrator`
   - `CloudFrontFullAccess`
   - `AmazonSESFullAccess`
   - `IAMFullAccess`
   - `CloudWatchLogsFullAccess`
7. Click **Next** → **Create user**

### 0.3 Generate Access Keys

1. Click on the user `digi-dan-deployer`
2. Go to **Security credentials** tab
3. Under **Access keys** → **Create access key**
4. Select **Command Line Interface (CLI)**
5. Check the confirmation checkbox → **Next** → **Create access key**
6. **SAVE both keys** — you won't see the secret key again:
   - `Access key ID`: AKIA...
   - `Secret access key`: ...

### 0.4 Install & Configure AWS CLI

```bash
# Install AWS CLI (Windows — download from):
# https://awscli.amazonaws.com/AWSCLIV2.msi
# Or via winget:
winget install Amazon.AWSCLI

# Configure with your new user's keys:
aws configure
# AWS Access Key ID:     <paste your access key>
# AWS Secret Access Key: <paste your secret key>
# Default region name:   il-central-1
# Default output format: json

# Verify it works:
aws sts get-caller-identity
```

You should see your account ID and the `digi-dan-deployer` user ARN.

### 0.5 Install Terraform

```bash
# Windows (via winget):
winget install Hashicorp.Terraform

# Verify:
terraform --version
```

---

## Step 1: First Deploy (Manual)

### 1.1 Deploy Infrastructure

```bash
cd terraform
terraform init
terraform apply
```

Review the plan and type `yes`. This creates:
- S3 bucket (private, CloudFront access only)
- DynamoDB table
- Lambda function
- API Gateway HTTP API
- CloudFront distribution with **Israel-only** geo-restriction

This takes ~5 minutes (CloudFront deployment is slow).

Note the outputs:
- `cloudfront_url` — your public site URL
- `api_url` — the API Gateway endpoint
- `s3_bucket_name` — the bucket name

### 1.2 Upload Site Files

Replace the API placeholder and upload:

```bash
# Get the API URL from terraform output:
API_URL=$(terraform output -raw api_url)
BUCKET=$(terraform output -raw s3_bucket_name)
CF_ID=$(terraform output -raw cloudfront_distribution_id)

# Go back to project root:
cd ..

# Create a deploy copy with the real API URL injected:
sed "s|{{API_GATEWAY_URL}}|$API_URL|g" index.html > _deploy.html

# Upload files to S3:
aws s3 cp _deploy.html "s3://$BUCKET/index.html" \
  --content-type "text/html; charset=utf-8" --region il-central-1
aws s3 cp logo.png "s3://$BUCKET/logo.png" \
  --content-type "image/png" --region il-central-1
aws s3 cp logo-with-text.png "s3://$BUCKET/logo-with-text.png" \
  --content-type "image/png" --region il-central-1

# Clean up temp file:
rm _deploy.html

# Invalidate CloudFront cache:
aws cloudfront create-invalidation \
  --distribution-id "$CF_ID" --paths "/*"
```

### 1.3 Verify Email in SES

For email notifications to `tichnundan@gmail.com`:

```bash
aws ses verify-email-identity \
  --email-address tichnundan@gmail.com \
  --region il-central-1
```

Check the inbox for `tichnundan@gmail.com` and click the verification link.

> **Note:** SES starts in sandbox mode. In sandbox, you can only send TO
> verified emails. Since both sender and receiver are `tichnundan@gmail.com`,
> this works. For sending to arbitrary addresses later, request SES production access.

### 1.4 Test It

Open the `cloudfront_url` from your Terraform output in a browser (from an Israeli IP).
Fill out the form and submit. Check:
- DynamoDB for the stored application
- `tichnundan@gmail.com` for the notification email

---

## Step 2: Enable Remote State (for CI/CD)

Before enabling CI/CD, create a Terraform state bucket so state persists between runs:

```bash
# Create the state bucket:
aws s3 mb s3://digi-dan-oss-tfstate --region il-central-1

# Enable versioning (protects against accidental state deletion):
aws s3api put-bucket-versioning \
  --bucket digi-dan-oss-tfstate \
  --versioning-configuration Status=Enabled \
  --region il-central-1
```

Then uncomment the `backend "s3"` block in `terraform/main.tf` and run:

```bash
cd terraform
terraform init -migrate-state
```

Type `yes` to copy local state to S3.

---

## Step 3: Set Up CI/CD (GitHub Actions)

The workflow at `.github/workflows/deploy.yml` auto-deploys on every push to `main`.

### 3.1 Add GitHub Secrets

Go to your repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:

| Secret Name | Value |
|------------|-------|
| `AWS_ACCESS_KEY_ID` | Your access key ID |
| `AWS_SECRET_ACCESS_KEY` | Your secret access key |

### 3.2 How CI/CD Works

On every push to `main`:

1. **Checkout** — pulls latest code
2. **AWS Credentials** — authenticates using your GitHub secrets
3. **Terraform Init + Apply** — creates/updates all infrastructure
4. **Get Outputs** — reads API URL, bucket name, CloudFront ID
5. **Inject API URL** — replaces `{{API_GATEWAY_URL}}` in index.html
6. **Upload to S3** — syncs HTML + logos to the bucket
7. **Invalidate CloudFront** — clears CDN cache so changes go live immediately

**Workflow:** Edit code → Push to `main` → GitHub deploys automatically → Live in ~2 minutes

You can also trigger it manually from GitHub → Actions → Deploy → **Run workflow**.

---

## Viewing Applications

```bash
# List all applications:
aws dynamodb scan \
  --table-name community-applications \
  --region il-central-1

# Find by email:
aws dynamodb query \
  --table-name community-applications \
  --index-name email-index \
  --key-condition-expression "email = :e" \
  --expression-attribute-values '{":e":{"S":"jane@example.com"}}' \
  --region il-central-1

# Approve an application:
aws dynamodb update-item \
  --table-name community-applications \
  --key '{"id":{"S":"<application-id>"}}' \
  --update-expression "SET #s = :s" \
  --expression-attribute-names '{"#s":"status"}' \
  --expression-attribute-values '{":s":{"S":"approved"}}' \
  --region il-central-1
```

---

## Security Notes

- **Geo-restriction:** CloudFront only serves to Israeli IPs
- **API throttle:** 5 req/sec, 10 burst
- **Lambda concurrency:** capped at 10
- **S3:** private, only accessible via CloudFront (no public URL)
- **DynamoDB:** encrypted at rest, point-in-time recovery enabled
- **CORS:** `*` — tighten to CloudFront domain after deploy
- No CAPTCHA — add Google reCAPTCHA if spam becomes an issue
