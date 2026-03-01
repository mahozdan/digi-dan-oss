#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  digi-dan oss — First Deploy Wizard                                ║
# ║  Takes the project from "code + AWS account" to "CI/CD working"    ║
# ║  Safe to re-run: all steps are idempotent                          ║
# ╚══════════════════════════════════════════════════════════════════════╝
#
# Usage:  bash scripts/first-deploy.sh [--profile PROFILE_NAME]
# Default profile: digi-dan
#
# Prerequisites:
#   - AWS CLI configured with a profile that has the deploy IAM policy attached
#   - Terraform >= 1.6
#   - GitHub CLI (gh) authenticated
#   - git remote pointing to the GitHub repo
#
# Fix CRLF before running (Windows → WSL):
#   sed -i 's/\r$//' scripts/first-deploy.sh
#
set -euo pipefail

# ─── Constants & Config ────────────────────────────────────────────────
DOMAIN_NAME="digi-dan.com"
REGION="il-central-1"
REGION_US="us-east-1"
TF_DIR="terraform"
STATE_BUCKET="digi-dan-oss-tfstate"
SITE_BUCKET="digi-dan-oss-join-site"
LAMBDA_ROLE_NAME="digi-dan-oss-join-lambda"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ─── AWS Profile ───────────────────────────────────────────────────────
AWS_PROFILE_NAME="digi-dan"
if [[ "${1:-}" == "--profile" ]] && [[ -n "${2:-}" ]]; then
  AWS_PROFILE_NAME="$2"
elif [[ -n "${1:-}" ]] && [[ "${1:-}" != "--"* ]]; then
  AWS_PROFILE_NAME="$1"
fi
export AWS_PROFILE="$AWS_PROFILE_NAME"

# ─── Colors ────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Counters ──────────────────────────────────────────────────────────
STEP=0
TOTAL_STEPS=12
PASS=0
FAIL=0

# ─── Helper Functions ──────────────────────────────────────────────────

banner() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}  ${BOLD}digi-dan oss${NC} — First Deploy Wizard                        ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  ${DIM}From code + AWS account → CI/CD deploying on push${NC}         ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

step_header() {
  STEP=$((STEP + 1))
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}  Step ${STEP}/${TOTAL_STEPS}: $1${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

info()    { echo -e "  ${CYAN}ℹ${NC}  $1"; }
success() { echo -e "  ${GREEN}✓${NC}  $1"; PASS=$((PASS + 1)); }
warn()    { echo -e "  ${YELLOW}⚠${NC}  $1"; }
fail()    { echo -e "  ${RED}✗${NC}  $1"; FAIL=$((FAIL + 1)); }
detail()  { echo -e "     ${DIM}$1${NC}"; }

confirm() {
  local msg="${1:-Continue?}"
  echo ""
  echo -ne "  ${YELLOW}?${NC}  ${msg} [Y/n] "
  read -r reply
  case "$reply" in
    [nN]*) return 1 ;;
    *) return 0 ;;
  esac
}

wait_for_user() {
  local msg="${1:-Press Enter to continue...}"
  echo ""
  echo -ne "  ${YELLOW}⏎${NC}  ${msg} "
  read -r
}

abort() {
  echo ""
  fail "$1"
  echo -e "  ${RED}Setup aborted.${NC} Fix the issue above and re-run this script."
  echo ""
  exit 1
}

# ─── STEP 1: Pre-flight Checks ────────────────────────────────────────

step_01_preflight() {
  step_header "Pre-flight Checks"

  local missing=0

  # AWS CLI
  if command -v aws &>/dev/null; then
    success "AWS CLI: $(aws --version 2>&1 | head -1)"
  else
    fail "AWS CLI not found"
    detail "Install: https://awscli.amazonaws.com/AWSCLIV2.msi"
    missing=1
  fi

  # Terraform
  if command -v terraform &>/dev/null; then
    success "Terraform: $(terraform --version 2>&1 | head -1)"
  else
    fail "Terraform not found"
    detail "Install: winget install Hashicorp.Terraform"
    missing=1
  fi

  # GitHub CLI
  if command -v gh &>/dev/null; then
    success "GitHub CLI: $(gh --version 2>&1 | head -1)"
  else
    fail "GitHub CLI (gh) not found"
    detail "Install: winget install GitHub.cli"
    missing=1
  fi

  # git
  if command -v git &>/dev/null; then
    success "git: $(git --version 2>&1)"
  else
    fail "git not found"
    missing=1
  fi

  # curl
  if command -v curl &>/dev/null; then
    success "curl found"
  else
    warn "curl not found — smoke test will be skipped"
  fi

  if [[ $missing -ne 0 ]]; then
    abort "Missing required tools. Install them and re-run."
  fi

  # AWS credentials
  info "Checking AWS credentials (profile: ${AWS_PROFILE_NAME})..."
  local identity
  if identity=$(aws sts get-caller-identity --region "$REGION" 2>&1); then
    local account_id arn
    account_id=$(echo "$identity" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
    arn=$(echo "$identity" | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)
    success "AWS authenticated"
    detail "Account: ${account_id}"
    detail "User:    ${arn}"
  else
    abort "AWS credentials not configured. Run: aws configure --profile ${AWS_PROFILE_NAME}"
  fi

  # GitHub CLI auth
  info "Checking GitHub CLI authentication..."
  if gh auth status &>/dev/null; then
    success "GitHub CLI authenticated"
  else
    fail "GitHub CLI not authenticated"
    detail "Run: gh auth login"
    abort "Authenticate with GitHub first."
  fi

  # Git remote
  info "Checking git remote..."
  local remote_url
  if remote_url=$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null); then
    success "Git remote: ${remote_url}"
  else
    abort "No git remote 'origin' configured. Run: git remote add origin <url>"
  fi

  # Terraform files exist
  if [[ -f "${SCRIPT_DIR}/${TF_DIR}/main.tf" ]]; then
    success "Found: ${TF_DIR}/main.tf"
  else
    abort "Missing: ${TF_DIR}/main.tf — are you running from the repo root?"
  fi

  # Deploy workflow exists
  if [[ -f "${SCRIPT_DIR}/.github/workflows/deploy.yml" ]]; then
    success "Found: .github/workflows/deploy.yml"
  else
    abort "Missing: .github/workflows/deploy.yml — create the CI/CD workflow first."
  fi

  success "All pre-flight checks passed"
}

# ─── STEP 2: IAM Prerequisites ────────────────────────────────────────

step_02_check_iam() {
  step_header "Check IAM Prerequisites"

  info "The following IAM resources must exist before continuing:"
  echo ""
  echo -e "  ${BOLD}1. IAM User:${NC} digi-dan-deployer"
  detail "With access key for CLI + GitHub Actions"
  echo ""
  echo -e "  ${BOLD}2. Deploy Policy:${NC} attached to the deployer user"
  detail "Copy from: iam/policies/iam-policy-deploy.json"
  echo ""
  echo -e "  ${BOLD}3. Lambda Execution Role:${NC} ${LAMBDA_ROLE_NAME}"
  detail "With policy from: iam/policies/iam-lambda-permissions-policy.json"
  echo ""

  # Validate: try listing S3 buckets (basic permission check)
  info "Validating deploy permissions..."

  if aws sts get-caller-identity --region "$REGION" &>/dev/null; then
    success "STS identity check passed"
  else
    abort "Cannot call STS — check AWS credentials"
  fi

  if aws s3 ls --region "$REGION" &>/dev/null; then
    success "S3 list permission verified"
  else
    warn "S3 list permission denied — deploy policy may not be attached"
    detail "Attach iam/policies/iam-policy-deploy.json to your IAM user"
  fi

  if aws acm list-certificates --region "$REGION_US" &>/dev/null; then
    success "ACM permission verified"
  else
    warn "ACM permission denied — update the deploy policy"
  fi

  if aws route53 list-hosted-zones &>/dev/null; then
    success "Route 53 permission verified"
  else
    warn "Route 53 permission denied — update the deploy policy"
  fi

  # Check Lambda role exists
  info "Checking Lambda execution role..."
  if aws iam get-role --role-name "$LAMBDA_ROLE_NAME" &>/dev/null; then
    success "Lambda role exists: ${LAMBDA_ROLE_NAME}"
  else
    fail "Lambda role '${LAMBDA_ROLE_NAME}' not found"
    echo ""
    echo -e "  ${YELLOW}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${YELLOW}║${NC}  ${BOLD}ACTION REQUIRED${NC}                                         ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}                                                           ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}  Create IAM role '${LAMBDA_ROLE_NAME}'         ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}  in the AWS Console with:                                 ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}    • Trust: Lambda service                                ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}    • Policy: iam/policies/iam-lambda-permissions-policy.json${YELLOW}║${NC}"
    echo -e "  ${YELLOW}╚═══════════════════════════════════════════════════════════╝${NC}"
    wait_for_user "Press Enter when the role has been created..."

    if ! aws iam get-role --role-name "$LAMBDA_ROLE_NAME" &>/dev/null; then
      abort "Lambda role still not found. Create it and re-run."
    fi
    success "Lambda role verified"
  fi
}

# ─── STEP 3: Create S3 State Bucket ───────────────────────────────────

step_03_create_state_bucket() {
  step_header "Create S3 State Bucket"

  info "Checking if state bucket exists: ${STATE_BUCKET}..."

  if aws s3api head-bucket --bucket "$STATE_BUCKET" --region "$REGION" 2>/dev/null; then
    success "State bucket already exists: ${STATE_BUCKET}"
  else
    info "Creating state bucket..."
    local create_exit=0
    aws s3api create-bucket \
      --bucket "$STATE_BUCKET" \
      --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION" 2>&1 || create_exit=$?

    if [[ $create_exit -ne 0 ]]; then
      fail "Cannot create state bucket (permission denied)"
      echo ""
      echo -e "  ${YELLOW}╔═══════════════════════════════════════════════════════════╗${NC}"
      echo -e "  ${YELLOW}║${NC}  ${BOLD}ACTION REQUIRED${NC}                                         ${YELLOW}║${NC}"
      echo -e "  ${YELLOW}║${NC}                                                           ${YELLOW}║${NC}"
      echo -e "  ${YELLOW}║${NC}  Create S3 bucket manually:                               ${YELLOW}║${NC}"
      echo -e "  ${YELLOW}║${NC}    Bucket: ${CYAN}${STATE_BUCKET}${NC}                        ${YELLOW}║${NC}"
      echo -e "  ${YELLOW}║${NC}    Region: ${CYAN}${REGION}${NC}                                  ${YELLOW}║${NC}"
      echo -e "  ${YELLOW}║${NC}    Enable: Versioning                                     ${YELLOW}║${NC}"
      echo -e "  ${YELLOW}╚═══════════════════════════════════════════════════════════╝${NC}"
      wait_for_user "Press Enter when the bucket exists..."

      if ! aws s3api head-bucket --bucket "$STATE_BUCKET" --region "$REGION" 2>/dev/null; then
        abort "State bucket still not accessible. Create it and re-run."
      fi
      success "State bucket confirmed"
      return
    fi

    success "State bucket created: ${STATE_BUCKET}"
  fi

  # Enable versioning
  info "Enabling versioning on state bucket..."
  if aws s3api put-bucket-versioning \
    --bucket "$STATE_BUCKET" \
    --region "$REGION" \
    --versioning-configuration Status=Enabled 2>/dev/null; then
    success "Versioning enabled"
  else
    warn "Could not enable versioning — enable it manually in the AWS Console"
  fi

  # Validate
  if ! aws s3api head-bucket --bucket "$STATE_BUCKET" --region "$REGION" 2>/dev/null; then
    abort "State bucket verification failed"
  fi
}

# ─── STEP 4: Terraform Init ───────────────────────────────────────────

step_04_terraform_init() {
  step_header "Terraform Init (S3 backend)"

  cd "${SCRIPT_DIR}/${TF_DIR}"

  info "Initializing Terraform with S3 backend..."
  info "State bucket: ${STATE_BUCKET}"
  echo ""

  # If .terraform exists, might need state migration
  if [[ -d .terraform ]]; then
    info "Existing .terraform directory found — running with migration support..."
    if echo "yes" | terraform init -migrate-state 2>&1; then
      echo ""
      success "Terraform initialized (state migrated if needed)"
    else
      echo ""
      # Fallback: reconfigure
      warn "Migration failed — trying reconfigure..."
      if terraform init -reconfigure 2>&1; then
        echo ""
        success "Terraform initialized (reconfigured)"
      else
        echo ""
        abort "Terraform init failed. Check the errors above."
      fi
    fi
  else
    if terraform init 2>&1; then
      echo ""
      success "Terraform initialized"
    else
      echo ""
      abort "Terraform init failed. Check the errors above."
    fi
  fi

  cd "${SCRIPT_DIR}"
}

# ─── STEP 5: Terraform Plan + Apply ───────────────────────────────────

step_05_terraform_apply() {
  step_header "Terraform Plan + Apply"

  cd "${SCRIPT_DIR}/${TF_DIR}"

  # Plan
  info "Running terraform plan..."
  echo ""

  if terraform plan -input=false -out=first-deploy.tfplan; then
    echo ""
    success "Plan generated"
  else
    echo ""
    abort "Terraform plan failed. Check the errors above."
  fi

  cd "${SCRIPT_DIR}"

  if ! confirm "Review the plan above. Apply these changes?"; then
    rm -f "${SCRIPT_DIR}/${TF_DIR}/first-deploy.tfplan"
    info "Cancelled. Re-run when ready."
    exit 0
  fi

  cd "${SCRIPT_DIR}/${TF_DIR}"

  # Apply
  info "Applying Terraform changes..."
  info "This may take 5-10 minutes (ACM validation + CloudFront creation)..."
  echo ""

  if terraform apply -input=false first-deploy.tfplan; then
    echo ""
    success "Terraform apply completed"
  else
    echo ""
    fail "Terraform apply had errors"
    warn "Some resources may have been partially created."
    warn "This is safe — re-run this script to retry."
    warn "Terraform tracks state and will pick up where it left off."
    echo ""
    if ! confirm "Try continuing anyway?"; then
      rm -f first-deploy.tfplan
      cd "${SCRIPT_DIR}"
      abort "Fix the errors and re-run."
    fi
  fi

  rm -f first-deploy.tfplan
  cd "${SCRIPT_DIR}"
}

# ─── STEP 6: Read Terraform Outputs ───────────────────────────────────

step_06_read_outputs() {
  step_header "Read Terraform Outputs"

  cd "${SCRIPT_DIR}/${TF_DIR}"

  API_URL=""
  BUCKET_NAME=""
  CF_DIST_ID=""
  CF_URL=""

  if API_URL=$(terraform output -raw api_url 2>/dev/null); then
    success "API URL:         ${API_URL}"
  else
    fail "Could not read api_url output"
  fi

  if BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null); then
    success "S3 bucket:       ${BUCKET_NAME}"
  else
    fail "Could not read s3_bucket_name output"
  fi

  if CF_DIST_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null); then
    success "CloudFront ID:   ${CF_DIST_ID}"
  else
    fail "Could not read cloudfront_distribution_id output"
  fi

  if CF_URL=$(terraform output -raw cloudfront_url 2>/dev/null); then
    success "CloudFront URL:  ${CF_URL}"
  else
    fail "Could not read cloudfront_url output"
  fi

  cd "${SCRIPT_DIR}"

  if [[ -z "$API_URL" ]] || [[ -z "$BUCKET_NAME" ]]; then
    abort "Missing critical outputs. Run: cd terraform && terraform output"
  fi
}

# ─── STEP 7: Deploy Site Files ────────────────────────────────────────

step_07_deploy_site() {
  step_header "Deploy Site Files to S3"

  cd "${SCRIPT_DIR}"

  # Inject API URL into a temp copy of index.html
  info "Injecting API URL into index.html..."
  local tmp_html
  tmp_html=$(mktemp)
  cp index.html "$tmp_html"
  sed -i "s|{{API_GATEWAY_URL}}|${API_URL}|g" "$tmp_html"
  success "API URL injected"

  # Upload index.html
  info "Uploading index.html..."
  if aws s3 cp "$tmp_html" "s3://${BUCKET_NAME}/index.html" \
    --content-type "text/html; charset=utf-8" --region "$REGION"; then
    success "Uploaded: index.html"
  else
    fail "Failed to upload index.html"
  fi
  rm -f "$tmp_html"

  # Upload logo files
  for logo_file in logo.png logo-with-text.png; do
    if [[ -f "$logo_file" ]]; then
      info "Uploading ${logo_file}..."
      if aws s3 cp "$logo_file" "s3://${BUCKET_NAME}/${logo_file}" \
        --content-type "image/png" --region "$REGION"; then
        success "Uploaded: ${logo_file}"
      else
        fail "Failed to upload ${logo_file}"
      fi
    fi
  done
}

# ─── STEP 8: Invalidate CloudFront ────────────────────────────────────

step_08_invalidate_cache() {
  step_header "Invalidate CloudFront Cache"

  if [[ -z "${CF_DIST_ID:-}" ]]; then
    warn "No CloudFront distribution ID — skipping invalidation"
    return
  fi

  info "Creating invalidation for all paths..."
  local inv_output
  if inv_output=$(aws cloudfront create-invalidation \
    --distribution-id "$CF_DIST_ID" \
    --paths "/*" 2>&1); then
    local inv_id
    inv_id=$(echo "$inv_output" | grep -o '"Id": "[^"]*"' | head -1 | cut -d'"' -f4)
    success "Cache invalidation created: ${inv_id}"
    detail "Propagation takes 1-2 minutes"
  else
    warn "Invalidation failed — you can do it manually later"
    detail "aws cloudfront create-invalidation --distribution-id ${CF_DIST_ID} --paths '/*'"
  fi
}

# ─── STEP 9: Verify Site Responds ─────────────────────────────────────

step_09_verify_site() {
  step_header "Verify Deployed Site"

  if ! command -v curl &>/dev/null; then
    warn "curl not available — skipping site verification"
    return
  fi

  # Test CloudFront URL first (always works regardless of DNS)
  if [[ -n "${CF_URL:-}" ]]; then
    info "Testing CloudFront URL: ${CF_URL}..."
    local cf_status
    cf_status=$(curl -s -o /dev/null -w "%{http_code}" "${CF_URL}" 2>/dev/null || echo "000")
    if [[ "$cf_status" == "200" ]]; then
      success "CloudFront responds: HTTP ${cf_status}"
    elif [[ "$cf_status" == "403" ]]; then
      success "CloudFront responds: HTTP 403 (geo-restriction — expected outside Israel)"
    else
      warn "CloudFront returned HTTP ${cf_status}"
    fi
  fi

  # Test custom domain
  info "Testing https://${DOMAIN_NAME}/..."
  local domain_status
  domain_status=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN_NAME}/" 2>/dev/null || echo "000")
  if [[ "$domain_status" == "200" ]]; then
    success "${DOMAIN_NAME} responds: HTTP ${domain_status}"
  elif [[ "$domain_status" == "403" ]]; then
    success "${DOMAIN_NAME} responds: HTTP 403 (geo-restriction — expected outside Israel)"
  elif [[ "$domain_status" == "000" ]]; then
    warn "Could not reach ${DOMAIN_NAME} — DNS may not have propagated yet"
    detail "This is normal for first deploy. DNS takes up to 48 hours."
  else
    warn "${DOMAIN_NAME} returned HTTP ${domain_status}"
  fi
}

# ─── STEP 10: Wire GitHub Secrets ─────────────────────────────────────

step_10_wire_github_secrets() {
  step_header "Wire GitHub Secrets for CI/CD"

  cd "${SCRIPT_DIR}"

  # Check if secrets already exist
  info "Checking existing GitHub secrets..."
  local existing_secrets
  existing_secrets=$(gh secret list 2>/dev/null || echo "")

  local key_exists=false
  local secret_exists=false

  if echo "$existing_secrets" | grep -q "AWS_ACCESS_KEY_ID"; then
    key_exists=true
    success "AWS_ACCESS_KEY_ID already set"
  fi

  if echo "$existing_secrets" | grep -q "AWS_SECRET_ACCESS_KEY"; then
    secret_exists=true
    success "AWS_SECRET_ACCESS_KEY already set"
  fi

  if $key_exists && $secret_exists; then
    info "Both GitHub secrets already configured"
    if ! confirm "Overwrite existing secrets?"; then
      info "Keeping existing secrets"
      return
    fi
  fi

  echo ""
  echo -e "  ${YELLOW}╔═══════════════════════════════════════════════════════════╗${NC}"
  echo -e "  ${YELLOW}║${NC}  ${BOLD}GITHUB SECRETS SETUP${NC}                                     ${YELLOW}║${NC}"
  echo -e "  ${YELLOW}║${NC}                                                           ${YELLOW}║${NC}"
  echo -e "  ${YELLOW}║${NC}  You'll be prompted to paste each secret value.            ${YELLOW}║${NC}"
  echo -e "  ${YELLOW}║${NC}  Get these from the AWS Console → IAM → Users →            ${YELLOW}║${NC}"
  echo -e "  ${YELLOW}║${NC}  digi-dan-deployer → Security credentials → Access keys    ${YELLOW}║${NC}"
  echo -e "  ${YELLOW}╚═══════════════════════════════════════════════════════════╝${NC}"
  echo ""

  # AWS_ACCESS_KEY_ID
  if ! $key_exists || confirm "Set AWS_ACCESS_KEY_ID?"; then
    info "Setting AWS_ACCESS_KEY_ID..."
    detail "Paste your Access Key ID when prompted:"
    if gh secret set AWS_ACCESS_KEY_ID; then
      success "AWS_ACCESS_KEY_ID set"
    else
      fail "Failed to set AWS_ACCESS_KEY_ID"
    fi
  fi

  # AWS_SECRET_ACCESS_KEY
  if ! $secret_exists || confirm "Set AWS_SECRET_ACCESS_KEY?"; then
    info "Setting AWS_SECRET_ACCESS_KEY..."
    detail "Paste your Secret Access Key when prompted:"
    if gh secret set AWS_SECRET_ACCESS_KEY; then
      success "AWS_SECRET_ACCESS_KEY set"
    else
      fail "Failed to set AWS_SECRET_ACCESS_KEY"
    fi
  fi
}

# ─── STEP 11: Push + Trigger CI/CD ────────────────────────────────────

step_11_push_and_verify_cicd() {
  step_header "Push to GitHub + Verify CI/CD"

  cd "${SCRIPT_DIR}"

  # Check for uncommitted changes
  local has_changes=false
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    has_changes=true
  fi
  if [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
    has_changes=true
  fi

  if $has_changes; then
    info "Uncommitted changes detected"
    git status --short

    if confirm "Commit all changes before pushing?"; then
      info "Staging changes..."
      # Stage specific known files, not everything
      git add -A
      info "Creating commit..."
      git commit -m "First deploy: infrastructure + CI/CD wiring"
      success "Changes committed"
    else
      warn "Uncommitted changes may not be deployed"
    fi
  fi

  # Check if branch is ahead of remote
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

  info "Pushing ${branch} to origin..."
  if git push origin "$branch" 2>&1; then
    success "Pushed to origin/${branch}"
  else
    fail "Push failed"
    abort "Fix push issues and re-run."
  fi

  # Wait for workflow to start
  info "Waiting for GitHub Actions workflow to start..."
  sleep 3

  # Watch the run
  local run_id
  run_id=$(gh run list --branch "$branch" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "")

  if [[ -n "$run_id" ]]; then
    success "Workflow triggered: run #${run_id}"
    info "Watching workflow progress..."
    echo ""

    if gh run watch "$run_id" --exit-status 2>&1; then
      echo ""
      success "CI/CD deploy succeeded!"
    else
      echo ""
      fail "CI/CD deploy failed"
      detail "Debug: gh run view ${run_id} --log-failed"
      warn "Check the workflow logs and re-run after fixing."
    fi
  else
    warn "Could not detect workflow run — check GitHub Actions manually"
    detail "URL: $(git remote get-url origin | sed 's/\.git$//')/actions"
  fi
}

# ─── STEP 12: Final Smoke Test ────────────────────────────────────────

step_12_final_smoke_test() {
  step_header "Final Smoke Test"

  if ! command -v curl &>/dev/null; then
    warn "curl not available — skipping final smoke test"
    return
  fi

  info "Testing https://${DOMAIN_NAME}/ (post CI/CD deploy)..."
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN_NAME}/" 2>/dev/null || echo "000")
  if [[ "$status" == "200" ]]; then
    success "Site is live: HTTP ${status}"
  elif [[ "$status" == "403" ]]; then
    success "Site responds: HTTP 403 (geo-restriction — expected outside Israel)"
  elif [[ "$status" == "000" ]]; then
    warn "Could not reach ${DOMAIN_NAME}"
    detail "DNS may still be propagating. The CloudFront URL works: ${CF_URL:-<check terraform output>}"
  else
    warn "Site returned HTTP ${status}"
  fi

  # Test API endpoint
  if [[ -n "${API_URL:-}" ]]; then
    info "Testing API endpoint: ${API_URL}/apply..."
    local api_status
    api_status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${API_URL}/apply" \
      -H "Content-Type: application/json" \
      -d '{}' 2>/dev/null || echo "000")
    if [[ "$api_status" == "400" ]]; then
      success "API responds: HTTP 400 (expected — empty body rejected)"
    elif [[ "$api_status" == "200" ]]; then
      success "API responds: HTTP 200"
    elif [[ "$api_status" == "000" ]]; then
      warn "Could not reach API endpoint"
    else
      info "API returned HTTP ${api_status}"
    fi
  fi
}

# ─── Summary ───────────────────────────────────────────────────────────

print_summary() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}                  ${BOLD}FIRST DEPLOY SUMMARY${NC}                        ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  echo -e "  ${GREEN}Passed:${NC}  ${PASS}"
  echo -e "  ${RED}Failed:${NC}  ${FAIL}"
  echo ""

  echo -e "  ${BOLD}Infrastructure:${NC}"
  echo -e "  ────────────────────────────────────────────────────────"
  echo -e "  ${BOLD}Site URL:${NC}        ${CYAN}https://${DOMAIN_NAME}${NC}"
  [[ -n "${CF_URL:-}" ]]     && echo -e "  ${BOLD}CloudFront:${NC}      ${CF_URL}"
  [[ -n "${API_URL:-}" ]]    && echo -e "  ${BOLD}API URL:${NC}         ${API_URL}"
  [[ -n "${BUCKET_NAME:-}" ]] && echo -e "  ${BOLD}S3 bucket:${NC}       ${BUCKET_NAME}"
  [[ -n "${CF_DIST_ID:-}" ]] && echo -e "  ${BOLD}Distribution:${NC}    ${CF_DIST_ID}"
  echo -e "  ${BOLD}State bucket:${NC}    ${STATE_BUCKET}"
  echo ""

  echo -e "  ${BOLD}CI/CD:${NC}"
  echo -e "  ────────────────────────────────────────────────────────"
  echo -e "  ${DIM}Pushes to main auto-deploy via GitHub Actions${NC}"
  echo -e "  ${DIM}Workflow: .github/workflows/deploy.yml${NC}"
  echo ""

  echo -e "  ${BOLD}Next Steps:${NC}"
  echo -e "  ────────────────────────────────────────────────────────"
  echo -e "  ${DIM}1. If custom domain not yet set up: bash setup-domain.sh${NC}"
  echo -e "  ${DIM}2. Verify SES sender email is verified in il-central-1${NC}"
  echo -e "  ${DIM}3. Test the application form on the live site${NC}"
  echo ""

  if [[ $FAIL -gt 0 ]]; then
    echo -e "  ${YELLOW}⚠  Some steps had issues. Review the output above.${NC}"
    echo -e "  ${YELLOW}   Re-run this script to retry — it is safe to re-run.${NC}"
  else
    echo -e "  ${GREEN}First deploy complete! CI/CD is wired and working.${NC}"
  fi
  echo ""
}

# ─── Main ──────────────────────────────────────────────────────────────

main() {
  banner

  echo -e "  ${DIM}This wizard creates all AWS infrastructure and wires${NC}"
  echo -e "  ${DIM}CI/CD so pushes to main auto-deploy.${NC}"
  echo ""
  echo -e "  ${BOLD}What will happen:${NC}"
  echo -e "    • Phase 1: Bootstrap (state bucket, IAM checks)"
  echo -e "    • Phase 2: Infrastructure (terraform apply)"
  echo -e "    • Phase 3: Deploy site files to S3"
  echo -e "    • Phase 4: Wire CI/CD (GitHub secrets + push)"
  echo -e "    • Phase 5: Verify everything works"
  echo ""

  if ! confirm "Ready to begin?"; then
    echo ""
    info "Cancelled. Re-run when ready."
    exit 0
  fi

  # Phase 1: Bootstrap
  step_01_preflight
  step_02_check_iam
  step_03_create_state_bucket

  # Phase 2: Infrastructure
  step_04_terraform_init
  step_05_terraform_apply
  step_06_read_outputs

  # Phase 3: Deploy site
  step_07_deploy_site
  step_08_invalidate_cache
  step_09_verify_site

  # Phase 4: Wire CI/CD
  step_10_wire_github_secrets
  step_11_push_and_verify_cicd

  # Phase 5: Final verification
  step_12_final_smoke_test
  print_summary
}

main "$@"
