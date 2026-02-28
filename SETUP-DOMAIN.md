# Domain Setup: digi-dan.com

Connect `digi-dan.com` and `www.digi-dan.com` to the CloudFront distribution.

## Prerequisites

| Requirement | Details |
|---|---|
| AWS CLI | `aws --version` |
| Terraform | `terraform --version` |
| Route 53 hosted zone | Must exist for `digi-dan.com` before running |
| Nameservers | Domain registrar must point to Route 53 NS records |
| IAM permissions | Deploy policy updated with ACM + Route 53 (see below) |

## IAM Policy Update

Before running the script, update the **digi-dan-deployer** policy in the AWS Console.

Copy the full policy from `iam/policies/iam-policy-deploy.json`. The new statements are:

- **ACMCertificates** — `acm:RequestCertificate`, `DescribeCertificate`, `ListCertificates`, `ListTagsForCertificate`, `AddTagsToCertificate`, `GetCertificate`
- **Route53Read** — `route53:GetHostedZone`, `ListHostedZones`, `ListResourceRecordSets`, `GetChange`, `ListTagsForResource`
- **Route53ManageRecords** — `route53:ChangeResourceRecordSets`

Also update the **digi-dan-destroyer** policy from `iam/policies/iam-policy-destroy.json`.

## Running the Script

```bash
# Fix line endings if running from Windows → WSL
sed -i 's/\r$//' setup-domain.sh

# Run the wizard
bash setup-domain.sh
```

## What the Script Does

| Step | Action | Duration |
|---|---|---|
| 1/7 | Pre-flight checks (tools, credentials) | ~5s |
| 2/7 | Verify Route 53 hosted zone + nameservers | ~5s |
| 3/7 | Check IAM permissions (ACM + Route 53) | ~5s |
| 4/7 | Terraform init (new us-east-1 provider) | ~15s |
| 5/7 | Terraform plan + apply | ~5-10 min |
| 6/7 | Read outputs + verify DNS | ~5s |
| 7/7 | Smoke test (curl apex + www) | ~5s |

The longest step is Terraform apply: ACM certificate validation takes 2-5 minutes, and CloudFront distribution update takes 3-5 minutes.

## What Gets Created

- **ACM certificate** in `us-east-1` covering `digi-dan.com` + `www.digi-dan.com`
- **DNS validation records** (CNAME) in Route 53 for certificate validation
- **A alias records** in Route 53: `digi-dan.com` → CloudFront, `www.digi-dan.com` → CloudFront
- **CloudFront aliases** updated with both domain names
- **TLS certificate** attached to CloudFront (sni-only, TLSv1.2)
- **CORS** tightened from `*` to `digi-dan.com` + `www.digi-dan.com`

## Re-running After Failure

The script is safe to re-run. Terraform tracks state:
- Already-created resources are skipped or updated in-place
- Failed resources are retried
- Certificate validation resumes where it left off

## DNS Propagation

After first run, DNS changes may take up to 48 hours to propagate globally. The CloudFront `*.cloudfront.net` URL continues to work during this period.

To check propagation:
```bash
dig A digi-dan.com +short
dig A www.digi-dan.com +short
```

## After Domain Setup

1. Re-upload site files (index.html now has `<link rel="canonical">`):
   ```bash
   bash deploy.sh  # re-run steps 9-10
   ```

2. Invalidate CloudFront cache:
   ```bash
   aws cloudfront create-invalidation \
     --profile digi-dan \
     --distribution-id $(cd terraform && terraform output -raw cloudfront_distribution_id) \
     --paths '/*'
   ```
