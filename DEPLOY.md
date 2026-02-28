# Join Site — Deployment Guide

## Architecture

```
Browser → S3 (static HTML) → User fills form
                ↓ POST /apply
         API Gateway (HTTP API)
                ↓
         Lambda (Node.js 20)
           ├── DynamoDB (store application)
           └── SES (email notification — optional)
```

## Cost Breakdown

| Component | Monthly Cost | Free Tier |
|-----------|-------------|-----------|
| S3 static hosting | ~$0.01 | 5GB storage, 20K GET free |
| API Gateway (HTTP API) | ~$0 | 1M requests free (12 months) |
| Lambda | ~$0 | 1M invocations free |
| DynamoDB (on-demand) | ~$0 | 25GB + 25 WCU/RCU free |
| SES (optional) | ~$0.10 | 62K emails free from Lambda |
| **Total** | **$0-1/mo** | |

For a community application page receiving <100 applications/month, you will stay in free tier indefinitely on everything except potentially SES (which is pennies).

## Deploy Steps

### 1. Deploy infrastructure

```bash
cd terraform
terraform init
terraform apply
```

Note the outputs:
- `website_url` — your site's public URL
- `api_url` — the API Gateway endpoint

### 2. Update the HTML

In `index.html`, replace the placeholder:

```javascript
// Find this line:
const API_ENDPOINT = '{{API_GATEWAY_URL}}/apply';

// Replace with your actual API Gateway URL:
const API_ENDPOINT = 'https://xxxxxxxxxx.execute-api.il-central-1.amazonaws.com/apply';
```

### 3. Upload the site

```bash
aws s3 cp index.html s3://community-join-site/index.html \
  --content-type "text/html" \
  --region il-central-1
```

### 4. (Optional) Configure email notifications

To receive email when someone applies:

1. Verify your email in SES:
```bash
aws ses verify-email-identity \
  --email-address admin@yourdomain.com \
  --region il-central-1
```

2. Re-apply Terraform with email variables:
```bash
terraform apply \
  -var="admin_email=admin@yourdomain.com" \
  -var="from_email=noreply@yourdomain.com"
```

Note: SES starts in sandbox mode. You can only send to verified emails until you request production access.

### 5. (Optional) Custom domain

To use a custom domain instead of the S3 URL:

1. Register/point a domain in Route53
2. Create a CloudFront distribution pointing to the S3 bucket
3. Attach an ACM certificate for HTTPS
4. This adds ~$1-2/mo for Route53 + minimal CloudFront costs

For initial launch, the S3 URL works fine.

## Viewing Applications

### CLI

```bash
# List all applications
aws dynamodb scan \
  --table-name community-applications \
  --region il-central-1

# Get applications by email
aws dynamodb query \
  --table-name community-applications \
  --index-name email-index \
  --key-condition-expression "email = :e" \
  --expression-attribute-values '{":e":{"S":"jane@example.com"}}' \
  --region il-central-1

# Update status (approve/reject)
aws dynamodb update-item \
  --table-name community-applications \
  --key '{"id":{"S":"<application-id>"}}' \
  --update-expression "SET #s = :s" \
  --expression-attribute-names '{"#s":"status"}' \
  --expression-attribute-values '{":s":{"S":"approved"}}' \
  --region il-central-1
```

## Security Notes

- API Gateway throttle: 5 req/sec, 10 burst — prevents abuse
- Lambda concurrency: capped at 10 — cost protection
- DynamoDB: encrypted at rest, point-in-time recovery enabled
- No authentication on the form (it's a public application page)
- CORS is set to `*` — tighten to your S3 domain after deploy
- No CAPTCHA yet — add if you get spam (Google reCAPTCHA is free)
