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

### Init + Plan + Apply Pattern
```bash
terraform -chdir="$TF_DIR" init
terraform -chdir="$TF_DIR" plan -out=tfplan
# Show plan, ask for confirmation
terraform -chdir="$TF_DIR" apply tfplan
```

### Reading Outputs
```bash
API_URL=$(terraform -chdir="$TF_DIR" output -raw api_url)
```

### Handling Partial Applies
Terraform state tracks what was created. Re-running `apply` after a partial failure will:
- Skip already-created resources
- Retry failed resources
- This is safe and expected

## Documentation
Every deploy script gets a companion `.md` file documenting:
- Prerequisites (tools, accounts, permissions)
- What each step does
- Manual actions required
- How to re-run after failure
- How to tear down / rollback

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
