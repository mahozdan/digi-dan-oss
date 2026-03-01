# writing-devops-scripts

## Philosophy
- Scripts are CLI wizards that guide the user step by step
- Do everything automatable; only pause for secrets/tokens
- Idempotent: safe to re-run after partial failures
- Validate every step before proceeding to the next

## Script Structure

```
#!/usr/bin/env bash
set -euo pipefail

# ─── Constants & Config ───
# ─── Color helpers ───
# ─── Utility functions ───
# ─── Pre-flight checks ───
# ─── Step functions (numbered) ───
# ─── Main flow ───
```

### Numbered Steps Pattern
Each step is a function with a clear name and number:
```bash
step_01_check_prerequisites() { ... }
step_02_configure_aws() { ... }
step_03_init_terraform() { ... }
```

Display progress: `Step 3/12: Terraform Init`

## Idempotency Rules

| Resource | Check Before Creating | Handle Exists |
|---|---|---|
| S3 bucket | `aws s3api head-bucket` | Skip with message |
| DynamoDB table | `aws dynamodb describe-table` | Skip with message |
| IAM user/role | `aws iam get-user/get-role` | Skip with message |
| Terraform state | Check `.terraform/` dir | Run init anyway (safe) |
| Config files | `[ -f file ]` | Ask overwrite or skip |

### Pattern: Check-or-Create
```bash
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  info "Bucket $BUCKET already exists — skipping"
else
  aws s3api create-bucket --bucket "$BUCKET" ...
  success "Bucket $BUCKET created"
fi
```

## Validation After Each Step
Every step must verify its own success:
```bash
# After creating a bucket
if ! aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  die "Failed to create bucket $BUCKET"
fi
```

## User Interaction

### Color-Coded Output
```bash
info()    { echo -e "\033[0;36m[INFO]\033[0m $*"; }
success() { echo -e "\033[0;32m[OK]\033[0m $*"; }
warn()    { echo -e "\033[0;33m[WARN]\033[0m $*"; }
die()     { echo -e "\033[0;31m[FAIL]\033[0m $*"; exit 1; }
```

### Confirmation Prompts
Ask before destructive or expensive operations:
```bash
read -rp "Proceed with Terraform apply? (y/N) " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || die "Aborted by user"
```

### Manual Steps
When the user must do something outside the script (e.g., verify an email, paste a token):
```bash
echo "─────────────────────────────────────────"
echo "ACTION REQUIRED: Verify the email sent to $EMAIL"
echo "Check your inbox and click the verification link."
echo "─────────────────────────────────────────"
read -rp "Press Enter when done..."
```

## Error Handling & Recovery

### Partial Failure
- Terraform tracks state — re-running apply after a partial failure is safe
- For non-Terraform resources, check existence before creating
- Print clear error messages with the failing command and next steps

### Common Sad Flows
| Scenario | Handling |
|---|---|
| Permission denied | Print the missing IAM action, link to policy file |
| Resource already exists | Skip with info message |
| Network timeout | Suggest retry, don't auto-retry in loops |
| Wrong region | Validate region in pre-flight checks |
| Missing CLI tool | Check in prerequisites, provide install command |
| Windows line endings | Script should start with note: `sed -i 's/\r$//' script.sh` |
| S3 bucket create denied | Provide manual AWS Console + CLI fallback, then `read -rp` to wait |
| Orphaned resources from failed deploys | Detect duplicates, warn user, pick correct one automatically |
| Terraform state migration prompt | Use `echo "yes" \| terraform init -migrate-state` |

### Pre-Flight Checks
Verify everything needed before starting any real work:
```bash
preflight() {
  command -v aws >/dev/null    || die "AWS CLI not found"
  command -v terraform >/dev/null || die "Terraform not found"
  command -v jq >/dev/null     || die "jq not found"
  aws sts get-caller-identity >/dev/null || die "AWS credentials not configured"
}
```

## Terraform Integration

### S3 Backend: Bootstrap Before Init
**Critical lesson**: Always create the S3 state bucket via AWS CLI *before* running `terraform init`. Never comment out or disable the S3 backend — this causes state loss and orphaned resources that require painful imports.

```bash
# Step 1: Create state bucket outside Terraform
aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null || \
  aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"
aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled

# Step 2: NOW run terraform init — backend is ready
terraform -chdir="$TF_DIR" init
```

**If bucket creation fails (permission denied)**: Provide clear manual fallback instructions, then wait for user confirmation before continuing.

### Init + Plan + Apply Pattern
```bash
terraform -chdir="$TF_DIR" init
terraform -chdir="$TF_DIR" plan -out=tfplan
# Show plan, ask for confirmation
terraform -chdir="$TF_DIR" apply tfplan
```

### State Migration (local → remote)
When moving from local state to S3 backend, `-input=false` will FAIL because Terraform needs interactive approval for state migration. Use:
```bash
echo "yes" | terraform init -migrate-state
```
Never use `-reconfigure` — it abandons local state instead of migrating it.

### Reading Outputs
```bash
API_URL=$(terraform -chdir="$TF_DIR" output -raw api_url)
```

### Handling Partial Applies
Terraform state tracks what was created. Re-running `apply` after a partial failure will:
- Skip already-created resources
- Retry failed resources
- This is safe and expected

### Import Pitfalls
- `aws_acm_certificate_validation` is a Terraform "waiter", not a real AWS resource — import often fails, but this is harmless if the cert and DNS validation records are imported
- Failed deploys without remote state create **duplicate resources** (API Gateways, ACM certs). Always detect and warn about duplicates
- When importing API Gateways with duplicates, pick the one with a Lambda integration attached

### CI/CD Wiring
A first-deploy script must verify CI/CD works before finishing:
1. Create state bucket → terraform init with S3 backend → apply
2. Set GitHub secrets via `gh secret set` (prompts user, script never touches the secret value)
3. Push to trigger workflow
4. Monitor workflow with `gh run watch`
5. Smoke test the deployed site

## Documentation
Every deploy script gets a companion `.md` file documenting:
- Prerequisites (tools, accounts, permissions)
- What each step does
- Manual actions required
- How to re-run after failure
- How to tear down / rollback

## AWS Profile Handling
- Default to the project-specific profile (e.g., `digi-dan`), never a generic name
- Support `--profile` flag override: `bash script.sh --profile my-profile`
- Export `AWS_PROFILE` early so all aws commands use it
- Show the active profile + account ID in pre-flight output

## Checklist
- [ ] `set -euo pipefail` at the top
- [ ] Pre-flight checks for all CLI tools and credentials
- [ ] Each step numbered and displayed to user
- [ ] Check-or-create pattern for all resources
- [ ] Validation after each step
- [ ] Color-coded output (info/success/warn/die)
- [ ] Confirmation before destructive operations
- [ ] Clear instructions for manual steps
- [ ] Companion documentation file
- [ ] Handles CRLF line endings (note in docs for Windows/WSL users)
- [ ] No secrets or tokens managed in the script
- [ ] AWS profile passed via `--profile` flag, not hardcoded credentials
- [ ] S3 state bucket created before terraform init
- [ ] Script finishes only when CI/CD is verified working
- [ ] Duplicate resource detection for re-runs after failed deploys
