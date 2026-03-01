# writing-first-deploy-script

Generate a first-deploy script that takes the project from "code + AWS account" to "CI/CD is wired and deploying on push to main."

## Script Lifecycle (must complete ALL phases)

### Phase 1: Bootstrap
1. Pre-flight checks (aws, terraform, gh, git, curl)
2. Verify AWS credentials + show account/identity
3. Prompt for IAM policy update (link to iam/policies/ files)
4. Create S3 state bucket via AWS CLI (BEFORE terraform init)
5. Enable versioning on state bucket

### Phase 2: Infrastructure
6. Terraform init with S3 backend (backend must be enabled from the start — never comment it out)
7. Terraform plan — show to user
8. Terraform apply — creates S3 site bucket, DynamoDB, Lambda, API Gateway, CloudFront, ACM cert, DNS records

### Phase 3: Deploy Site
9. Read terraform outputs (api_url, bucket, distribution_id)
10. Inject API URL into index.html (sed replace `{{API_GATEWAY_URL}}`)
11. Upload site files to S3
12. Invalidate CloudFront cache

### Phase 4: Wire CI/CD (THIS IS THE CRITICAL PHASE — script must not end before this)
13. Verify GitHub remote is configured
14. Verify .github/workflows/deploy.yml exists
15. Set GitHub secrets via `gh secret set` (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY) — `gh` handles secret input, script never touches the value
16. Commit and push all changes
17. Monitor GitHub Actions with `gh run watch`
18. Verify the CI/CD deploy succeeds

### Phase 5: Verification
19. Smoke test the deployed URL (curl)
20. Print summary with all URLs and next steps

## Critical Rules

### S3 Backend First
The #1 lesson: **never run terraform with local state if CI/CD will use remote state.** Create the state bucket via AWS CLI, then run `terraform init` with the S3 backend already configured in main.tf. This avoids orphaned resources and painful imports.

### State Migration
If local state already exists (re-run scenario), use:
```bash
echo "yes" | terraform init -migrate-state
```
Never use `-input=false` for migrations (it fails). Never use `-reconfigure` (it abandons local state).

### Duplicate Resource Detection
Failed deploys without remote state create orphans. The script should check for duplicates:
- API Gateways: `aws apigatewayv2 get-apis --query "Items[?Name=='...']"`
- ACM certs: `aws acm list-certificates --query "CertificateSummaryList[?DomainName=='...']"`
Warn the user and recommend manual cleanup after successful deploy.

### GitHub Secrets
Use `gh secret set NAME` which prompts interactively. The script must NEVER read, store, or pipe secret values — `gh` handles the secure input.

### CI/CD Verification
The script is NOT done until:
1. GitHub secrets are set
2. Code is pushed to main
3. GitHub Actions workflow runs successfully
4. The deployed site responds to curl

## Style
- Follow the patterns in `writing-devops-scripts.md` (numbered steps, color output, check-or-create, idempotent)
- Match the style of existing scripts like `setup-domain.sh` (banner, step_header, info/success/warn/fail helpers)
- Script can be as long as needed — scripts are NOT limited to 300 lines
- Companion `.md` documentation file required

## What This Replaces
A first-deploy script that stops after `terraform apply` is incomplete. The old pattern left CI/CD broken because:
1. Terraform ran with local state
2. State was never migrated to S3
3. CI/CD had no state → "already exists" errors on every resource
4. Required a separate tf-import.sh to fix

The new pattern avoids this entirely by starting with S3 backend from step 1.
