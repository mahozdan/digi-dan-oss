#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  digi-dan oss — First Deploy Wizard                                ║
# ║  Interactive CLI that provisions the entire AWS stack step by step  ║
# ║  Safe to re-run: skips resources that already exist                 ║
# ╚══════════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────
REGION="il-central-1"
AWS_PROFILE_NAME="digi-dan"
PROJECT="digi-dan-oss"
SITE_BUCKET="digi-dan-oss-join-site"
TFSTATE_BUCKET="digi-dan-oss-tfstate"
DYNAMO_TABLE="community-applications"
LAMBDA_NAME="digi-dan-oss-join-apply"
API_NAME="digi-dan-oss-join-api"
ADMIN_EMAIL="tichnundan@gmail.com"
GITHUB_REPO="mahozdan/digi-dan-oss"
TF_DIR="terraform"
LAMBDA_DIR="lambda/apply"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── AWS Profile ─────────────────────────────────────────────────────
# All aws CLI commands use --profile $AWS_PROFILE_NAME
# Terraform picks up credentials via the AWS_PROFILE env var
export AWS_PROFILE="$AWS_PROFILE_NAME"

# ─── Colors ───────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# ─── Counters ─────────────────────────────────────────────────────────
STEP=0
TOTAL_STEPS=12
PASS=0
FAIL=0
SKIP=0

# ─── Helper Functions ─────────────────────────────────────────────────

banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}digi-dan oss${NC} — First Deploy Wizard                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${DIM}Community join site · S3 + CloudFront + Lambda + DynamoDB${NC}  ${CYAN}║${NC}"
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
skipped() { echo -e "  ${DIM}⊘  $1 (already exists — skipped)${NC}"; SKIP=$((SKIP + 1)); }
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
    echo -e "  ${RED}Deploy aborted.${NC} Fix the issue above and re-run this script."
    echo ""
    exit 1
}

# Run a command, show output on failure, return exit code
run_cmd() {
    local output
    local exit_code=0
    output=$("$@" 2>&1) || exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo "$output"
    fi
    return $exit_code
}

# ─── STEP 1: Check Prerequisites ─────────────────────────────────────

check_prerequisites() {
    step_header "Check Prerequisites"

    local missing=0

    # AWS CLI
    if command -v aws &>/dev/null; then
        local aws_version
        aws_version=$(aws --version 2>&1 | head -1)
        success "AWS CLI found: ${aws_version}"
    else
        fail "AWS CLI not found"
        detail "Install: https://awscli.amazonaws.com/AWSCLIV2.msi"
        detail "Or: winget install Amazon.AWSCLI"
        missing=1
    fi

    # Terraform
    if command -v terraform &>/dev/null; then
        local tf_version
        tf_version=$(terraform --version 2>&1 | head -1)
        success "Terraform found: ${tf_version}"
    else
        fail "Terraform not found"
        detail "Install: winget install Hashicorp.Terraform"
        missing=1
    fi

    # Git
    if command -v git &>/dev/null; then
        success "Git found: $(git --version)"
    else
        fail "Git not found"
        missing=1
    fi

    # sed (for injecting API URL)
    if command -v sed &>/dev/null; then
        success "sed found"
    else
        fail "sed not found — needed to inject API URL into HTML"
        missing=1
    fi

    # GitHub CLI (optional — needed for automated CI/CD setup)
    if command -v gh &>/dev/null; then
        success "GitHub CLI found: $(gh --version | head -1)"
    else
        warn "GitHub CLI (gh) not found — CI/CD setup will require manual steps"
        detail "Install: winget install GitHub.cli"
        detail "Or: https://cli.github.com"
    fi

    # Check required project files exist
    local required_files=("index.html" "logo.png" "logo-with-text.png" "${TF_DIR}/main.tf" "${LAMBDA_DIR}/index.mjs")
    for f in "${required_files[@]}"; do
        if [[ -f "${SCRIPT_DIR}/${f}" ]]; then
            success "Found: ${f}"
        else
            fail "Missing: ${f}"
            missing=1
        fi
    done

    if [[ $missing -ne 0 ]]; then
        abort "Missing prerequisites. Install the tools above and re-run."
    fi

    success "All prerequisites met"
}

# ─── STEP 2: Verify AWS Credentials ──────────────────────────────────

verify_aws_credentials() {
    step_header "Verify AWS Credentials"

    info "Checking AWS CLI profile: ${BOLD}${AWS_PROFILE_NAME}${NC}"

    local identity
    if identity=$(aws sts get-caller-identity --profile "$AWS_PROFILE_NAME" --region "$REGION" 2>&1); then
        local account_id arn
        account_id=$(echo "$identity" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
        arn=$(echo "$identity" | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)
        success "Authenticated to AWS"
        detail "Account: ${account_id}"
        detail "User:    ${arn}"
    else
        fail "AWS credentials not configured or invalid"
        echo ""
        echo -e "  ${YELLOW}Run this manually:${NC}"
        echo ""
        echo "    aws configure --profile ${AWS_PROFILE_NAME}"
        echo "    # AWS Access Key ID:     <your key>"
        echo "    # AWS Secret Access Key: <your secret>"
        echo "    # Default region name:   il-central-1"
        echo "    # Default output format: json"
        echo ""
        abort "Configure AWS credentials with: aws configure --profile ${AWS_PROFILE_NAME}"
    fi

    # Verify the region is correct
    local configured_region
    configured_region=$(aws configure get region --profile "$AWS_PROFILE_NAME" 2>/dev/null || echo "")
    if [[ "$configured_region" == "$REGION" ]]; then
        success "Default region: ${REGION}"
    else
        warn "Default region is '${configured_region}', expected '${REGION}'"
        info "Terraform and all commands will explicitly use ${REGION}"
    fi
}

# ─── STEP 3: Check Existing Resources ────────────────────────────────

check_existing_resources() {
    step_header "Scan Existing Resources"

    info "Checking which resources already exist..."

    SITE_BUCKET_EXISTS=false
    DYNAMO_TABLE_EXISTS=false
    LAMBDA_EXISTS=false
    API_EXISTS=false
    CLOUDFRONT_EXISTS=false
    TFSTATE_BUCKET_EXISTS=false
    SES_VERIFIED=false

    # S3 site bucket
    if aws s3api head-bucket --bucket "$SITE_BUCKET" --profile "$AWS_PROFILE_NAME" --region "$REGION" 2>/dev/null; then
        SITE_BUCKET_EXISTS=true
        warn "S3 bucket '${SITE_BUCKET}' already exists"
    else
        info "S3 bucket '${SITE_BUCKET}' — will be created"
    fi

    # DynamoDB table
    if aws dynamodb describe-table --table-name "$DYNAMO_TABLE" --profile "$AWS_PROFILE_NAME" --region "$REGION" 2>/dev/null | grep -q "ACTIVE"; then
        DYNAMO_TABLE_EXISTS=true
        warn "DynamoDB table '${DYNAMO_TABLE}' already exists"
    else
        info "DynamoDB table '${DYNAMO_TABLE}' — will be created"
    fi

    # Lambda function
    if aws lambda get-function --function-name "$LAMBDA_NAME" --profile "$AWS_PROFILE_NAME" --region "$REGION" 2>/dev/null | grep -q "FunctionArn"; then
        LAMBDA_EXISTS=true
        warn "Lambda '${LAMBDA_NAME}' already exists"
    else
        info "Lambda '${LAMBDA_NAME}' — will be created"
    fi

    # API Gateway
    local apis
    apis=$(aws apigatewayv2 get-apis --profile "$AWS_PROFILE_NAME" --region "$REGION" 2>/dev/null || echo "")
    if echo "$apis" | grep -q "$API_NAME"; then
        API_EXISTS=true
        warn "API Gateway '${API_NAME}' already exists"
    else
        info "API Gateway '${API_NAME}' — will be created"
    fi

    # CloudFront (check by comment)
    local distributions
    distributions=$(aws cloudfront list-distributions --profile "$AWS_PROFILE_NAME" --region "$REGION" 2>/dev/null || echo "")
    if echo "$distributions" | grep -q "digi-dan oss join site"; then
        CLOUDFRONT_EXISTS=true
        warn "CloudFront distribution already exists"
    else
        info "CloudFront distribution — will be created"
    fi

    # TF state bucket
    if aws s3api head-bucket --bucket "$TFSTATE_BUCKET" --profile "$AWS_PROFILE_NAME" --region "$REGION" 2>/dev/null; then
        TFSTATE_BUCKET_EXISTS=true
        warn "TF state bucket '${TFSTATE_BUCKET}' already exists"
    else
        info "TF state bucket '${TFSTATE_BUCKET}' — will be created (Step 10)"
    fi

    # SES email verification
    local ses_identities
    ses_identities=$(aws ses list-verified-email-addresses --profile "$AWS_PROFILE_NAME" --region "$REGION" 2>/dev/null || echo "")
    if echo "$ses_identities" | grep -qi "$ADMIN_EMAIL"; then
        SES_VERIFIED=true
        warn "SES email '${ADMIN_EMAIL}' already verified"
    else
        info "SES email '${ADMIN_EMAIL}' — will need verification"
    fi

    local existing_count=0
    $SITE_BUCKET_EXISTS && existing_count=$((existing_count + 1))
    $DYNAMO_TABLE_EXISTS && existing_count=$((existing_count + 1))
    $LAMBDA_EXISTS && existing_count=$((existing_count + 1))
    $API_EXISTS && existing_count=$((existing_count + 1))
    $CLOUDFRONT_EXISTS && existing_count=$((existing_count + 1))

    echo ""
    if [[ $existing_count -gt 0 ]]; then
        warn "${existing_count} resource(s) already exist — Terraform will manage them (import or update)"
        info "This is safe. Terraform will reconcile existing state."
    else
        success "Clean slate — all resources will be created fresh"
    fi
}

# ─── STEP 4: Check Terraform State ───────────────────────────────────

check_terraform_state() {
    step_header "Check Terraform State"

    cd "${SCRIPT_DIR}/${TF_DIR}"

    if [[ -d ".terraform" ]]; then
        info "Terraform already initialized (.terraform/ exists)"
        info "Will re-initialize to ensure plugins are up to date"
    else
        info "Terraform not yet initialized"
    fi

    # Check for existing local state
    if [[ -f "terraform.tfstate" ]]; then
        warn "Local terraform.tfstate found"
        local resource_count
        resource_count=$(grep -c '"type"' terraform.tfstate 2>/dev/null || echo "0")
        detail "Contains ~${resource_count} resource definitions"
        info "Terraform will use existing state and reconcile"
    else
        info "No local state file — fresh deployment"
    fi

    cd "${SCRIPT_DIR}"
    success "Terraform state check complete"
}

# ─── STEP 5: Terraform Init ──────────────────────────────────────────

terraform_init() {
    step_header "Terraform Init"

    cd "${SCRIPT_DIR}/${TF_DIR}"

    info "Initializing Terraform providers..."
    echo ""

    if terraform init -input=false; then
        echo ""
        success "Terraform initialized successfully"
    else
        echo ""
        abort "Terraform init failed. Check the errors above."
    fi

    cd "${SCRIPT_DIR}"
}

# ─── STEP 6: Terraform Plan ──────────────────────────────────────────

terraform_plan() {
    step_header "Terraform Plan (dry-run)"

    cd "${SCRIPT_DIR}/${TF_DIR}"

    info "Running terraform plan to preview changes..."
    echo ""

    if terraform plan -input=false -out=deploy.tfplan; then
        echo ""
        success "Plan generated successfully"
    else
        echo ""
        abort "Terraform plan failed. Fix the errors above and re-run."
    fi

    cd "${SCRIPT_DIR}"

    if ! confirm "Review the plan above. Apply these changes?"; then
        echo ""
        info "You chose not to apply. Exiting."
        info "Re-run this script when ready."
        exit 0
    fi
}

# ─── STEP 7: Terraform Apply ─────────────────────────────────────────

terraform_apply() {
    step_header "Terraform Apply (provision infrastructure)"

    cd "${SCRIPT_DIR}/${TF_DIR}"

    info "Applying Terraform plan..."
    info "This may take 3-5 minutes (CloudFront is slow to provision)..."
    echo ""

    if terraform apply -input=false deploy.tfplan; then
        echo ""
        success "Terraform apply completed successfully"
    else
        echo ""
        fail "Terraform apply had errors"
        echo ""
        warn "Some resources may have been partially created."
        warn "This is normal — re-run this script to retry."
        warn "Terraform will pick up where it left off."
        echo ""
        if confirm "Try continuing anyway? (Some outputs might work)"; then
            warn "Continuing with partial deployment..."
        else
            abort "Fix the errors and re-run this script."
        fi
    fi

    # Clean up plan file
    rm -f deploy.tfplan

    cd "${SCRIPT_DIR}"
}

# ─── STEP 8: Read Terraform Outputs ──────────────────────────────────

read_outputs() {
    step_header "Read Terraform Outputs"

    cd "${SCRIPT_DIR}/${TF_DIR}"

    info "Extracting resource identifiers from Terraform..."

    API_URL=""
    BUCKET_NAME=""
    CF_DIST_ID=""
    CF_URL=""
    DYNAMO_TABLE_NAME=""

    # Read each output, handle failures individually
    if API_URL=$(terraform output -raw api_url 2>/dev/null); then
        success "API URL:          ${API_URL}"
    else
        fail "Could not read api_url output"
    fi

    if BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null); then
        success "S3 Bucket:        ${BUCKET_NAME}"
    else
        fail "Could not read s3_bucket_name output"
    fi

    if CF_DIST_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null); then
        success "CloudFront ID:    ${CF_DIST_ID}"
    else
        fail "Could not read cloudfront_distribution_id output"
    fi

    if CF_URL=$(terraform output -raw cloudfront_url 2>/dev/null); then
        success "CloudFront URL:   ${CF_URL}"
    else
        fail "Could not read cloudfront_url output"
    fi

    if DYNAMO_TABLE_NAME=$(terraform output -raw dynamodb_table 2>/dev/null); then
        success "DynamoDB Table:   ${DYNAMO_TABLE_NAME}"
    else
        fail "Could not read dynamodb_table output"
    fi

    cd "${SCRIPT_DIR}"

    # Validate critical outputs
    if [[ -z "$API_URL" || -z "$BUCKET_NAME" || -z "$CF_DIST_ID" ]]; then
        abort "Missing critical Terraform outputs. Run 'cd terraform && terraform output' to debug."
    fi
}

# ─── STEP 9: Upload Site Files ────────────────────────────────────────

upload_site_files() {
    step_header "Upload Site Files to S3"

    cd "${SCRIPT_DIR}"

    # Inject the API URL into index.html
    info "Injecting API URL into index.html..."

    if [[ ! -f "index.html" ]]; then
        abort "index.html not found in project root"
    fi

    # Create a deploy copy (never modify the original)
    cp index.html _deploy_index.html
    sed -i "s|{{API_GATEWAY_URL}}|${API_URL}|g" _deploy_index.html

    # Verify the placeholder was replaced
    if grep -q "{{API_GATEWAY_URL}}" _deploy_index.html; then
        fail "API URL placeholder was not replaced (might be already replaced or different format)"
        detail "Check index.html for the placeholder: {{API_GATEWAY_URL}}"
    else
        success "API URL injected: ${API_URL}"
    fi

    # Verify the API endpoint is now in the file
    if grep -q "${API_URL}" _deploy_index.html; then
        success "Verified: API endpoint found in deploy HTML"
    else
        warn "Could not verify API URL in HTML (may already be hardcoded)"
    fi

    # Upload index.html
    info "Uploading index.html..."
    if aws s3 cp _deploy_index.html "s3://${BUCKET_NAME}/index.html" \
        --profile "$AWS_PROFILE_NAME" \
        --content-type "text/html; charset=utf-8" \
        --region "$REGION"; then
        success "Uploaded: index.html"
    else
        fail "Failed to upload index.html"
    fi

    # Upload logo.png
    info "Uploading logo.png..."
    if aws s3 cp logo.png "s3://${BUCKET_NAME}/logo.png" \
        --profile "$AWS_PROFILE_NAME" \
        --content-type "image/png" \
        --region "$REGION"; then
        success "Uploaded: logo.png"
    else
        fail "Failed to upload logo.png"
    fi

    # Upload logo-with-text.png
    info "Uploading logo-with-text.png..."
    if aws s3 cp logo-with-text.png "s3://${BUCKET_NAME}/logo-with-text.png" \
        --profile "$AWS_PROFILE_NAME" \
        --content-type "image/png" \
        --region "$REGION"; then
        success "Uploaded: logo-with-text.png"
    else
        fail "Failed to upload logo-with-text.png"
    fi

    # Clean up temp file
    rm -f _deploy_index.html
    success "Cleaned up temporary deploy file"

    # Verify uploads
    info "Verifying S3 contents..."
    local s3_files
    s3_files=$(aws s3 ls "s3://${BUCKET_NAME}/" --profile "$AWS_PROFILE_NAME" --region "$REGION" 2>&1)
    if echo "$s3_files" | grep -q "index.html"; then
        success "Verified: index.html exists in S3"
    else
        fail "index.html NOT found in S3 bucket"
    fi
    if echo "$s3_files" | grep -q "logo.png"; then
        success "Verified: logo.png exists in S3"
    else
        fail "logo.png NOT found in S3 bucket"
    fi
    if echo "$s3_files" | grep -q "logo-with-text.png"; then
        success "Verified: logo-with-text.png exists in S3"
    else
        fail "logo-with-text.png NOT found in S3 bucket"
    fi
}

# ─── STEP 10: Invalidate CloudFront Cache ────────────────────────────

invalidate_cloudfront() {
    step_header "Invalidate CloudFront Cache"

    info "Creating CloudFront cache invalidation..."

    local invalidation_output
    if invalidation_output=$(aws cloudfront create-invalidation \
        --profile "$AWS_PROFILE_NAME" \
        --distribution-id "$CF_DIST_ID" \
        --paths "/*" 2>&1); then
        local inv_id
        inv_id=$(echo "$invalidation_output" | grep -o '"Id": "[^"]*"' | head -1 | cut -d'"' -f4)
        success "Invalidation created: ${inv_id}"
        detail "Cache clearing takes 1-2 minutes to complete"
    else
        fail "CloudFront invalidation failed"
        echo "$invalidation_output"
        warn "The site may still serve stale content. You can retry manually:"
        detail "aws cloudfront create-invalidation --profile ${AWS_PROFILE_NAME} --distribution-id ${CF_DIST_ID} --paths '/*'"
    fi
}

# ─── STEP 11: Verify SES Email ───────────────────────────────────────

verify_ses_email() {
    step_header "Verify SES Email Identity"

    if $SES_VERIFIED; then
        skipped "SES email '${ADMIN_EMAIL}' already verified"
        return
    fi

    info "Requesting SES email verification for: ${ADMIN_EMAIL}"

    if aws ses verify-email-identity \
        --profile "$AWS_PROFILE_NAME" \
        --email-address "$ADMIN_EMAIL" \
        --region "$REGION" 2>/dev/null; then
        success "Verification email sent to ${ADMIN_EMAIL}"
        echo ""
        echo -e "  ${YELLOW}╔═══════════════════════════════════════════════════════╗${NC}"
        echo -e "  ${YELLOW}║${NC}  ${BOLD}ACTION REQUIRED (manual)${NC}                            ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}                                                       ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  1. Open the inbox for: ${CYAN}${ADMIN_EMAIL}${NC}    ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  2. Find the email from Amazon Web Services            ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  3. Click the verification link                        ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}                                                       ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  ${DIM}SES is in sandbox mode: can only send TO verified${NC}   ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  ${DIM}addresses. Since admin = sender, this is fine.${NC}      ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}╚═══════════════════════════════════════════════════════╝${NC}"
        echo ""

        wait_for_user "Click the verification link, then press Enter..."

        # Verify it worked
        local verified_emails
        verified_emails=$(aws ses list-verified-email-addresses --profile "$AWS_PROFILE_NAME" --region "$REGION" 2>/dev/null || echo "")
        if echo "$verified_emails" | grep -qi "$ADMIN_EMAIL"; then
            success "Email verified successfully!"
        else
            warn "Email not yet verified. You can verify later — notifications won't work until then."
            detail "To re-send: aws ses verify-email-identity --profile ${AWS_PROFILE_NAME} --email-address ${ADMIN_EMAIL} --region ${REGION}"
        fi
    else
        fail "Failed to send SES verification email"
        detail "Try manually: aws ses verify-email-identity --profile ${AWS_PROFILE_NAME} --email-address ${ADMIN_EMAIL} --region ${REGION}"
    fi
}

# ─── STEP 12: Create TF Remote State Bucket ──────────────────────────

setup_remote_state() {
    step_header "Create Terraform Remote State Bucket"

    info "Remote state allows CI/CD and team collaboration"

    if $TFSTATE_BUCKET_EXISTS; then
        skipped "TF state bucket '${TFSTATE_BUCKET}'"

        # Still check versioning
        local versioning
        versioning=$(aws s3api get-bucket-versioning --bucket "$TFSTATE_BUCKET" --profile "$AWS_PROFILE_NAME" --region "$REGION" 2>/dev/null || echo "")
        if echo "$versioning" | grep -q '"Enabled"'; then
            success "Versioning already enabled on state bucket"
        else
            info "Enabling versioning on state bucket..."
            if aws s3api put-bucket-versioning \
                --bucket "$TFSTATE_BUCKET" \
                --profile "$AWS_PROFILE_NAME" \
                --versioning-configuration Status=Enabled \
                --region "$REGION" 2>/dev/null; then
                success "Versioning enabled"
            else
                warn "Could not enable versioning — enable manually"
            fi
        fi
        return
    fi

    if ! confirm "Create remote state bucket '${TFSTATE_BUCKET}'? (Recommended for CI/CD)"; then
        info "Skipping remote state. You can set this up later."
        return
    fi

    # Create bucket
    info "Creating S3 bucket: ${TFSTATE_BUCKET}..."
    if aws s3 mb "s3://${TFSTATE_BUCKET}" --profile "$AWS_PROFILE_NAME" --region "$REGION" 2>/dev/null; then
        success "State bucket created: ${TFSTATE_BUCKET}"
    else
        fail "Failed to create state bucket"
        detail "It may already exist in another account, or the name is taken globally."
        detail "Try a different name by editing TFSTATE_BUCKET in this script."
        return
    fi

    # Enable versioning
    info "Enabling versioning (protects against accidental state deletion)..."
    if aws s3api put-bucket-versioning \
        --bucket "$TFSTATE_BUCKET" \
        --profile "$AWS_PROFILE_NAME" \
        --versioning-configuration Status=Enabled \
        --region "$REGION" 2>/dev/null; then
        success "Versioning enabled on state bucket"
    else
        warn "Could not enable versioning"
    fi

    # Enable encryption
    info "Enabling server-side encryption..."
    if aws s3api put-bucket-encryption \
        --bucket "$TFSTATE_BUCKET" \
        --profile "$AWS_PROFILE_NAME" \
        --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
        --region "$REGION" 2>/dev/null; then
        success "Encryption enabled on state bucket"
    else
        warn "Could not enable encryption"
    fi

    # Block public access
    info "Blocking public access..."
    if aws s3api put-public-access-block \
        --bucket "$TFSTATE_BUCKET" \
        --profile "$AWS_PROFILE_NAME" \
        --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
        --region "$REGION" 2>/dev/null; then
        success "Public access blocked on state bucket"
    else
        warn "Could not block public access"
    fi

    echo ""
    info "To migrate local state to this bucket, run:"
    echo ""
    echo -e "  ${DIM}1. Uncomment the backend \"s3\" block in terraform/main.tf${NC}"
    echo -e "  ${DIM}2. cd terraform && terraform init -migrate-state${NC}"
    echo -e "  ${DIM}3. Type 'yes' to copy state to S3${NC}"
    echo ""
}

# ─── STEP 13: Setup GitHub Actions (Optional) ────────────────────────

setup_github_actions() {
    step_header "GitHub Actions CI/CD (Optional)"

    if ! command -v gh &>/dev/null; then
        info "GitHub CLI (gh) not installed — skipping automated setup"
        echo ""
        echo -e "  ${YELLOW}To set up CI/CD manually:${NC}"
        echo ""
        echo "  1. Go to: https://github.com/${GITHUB_REPO}/settings/secrets/actions"
        echo "  2. Add these repository secrets:"
        echo ""
        echo -e "     ${BOLD}AWS_ACCESS_KEY_ID${NC}      → Your access key ID"
        echo -e "     ${BOLD}AWS_SECRET_ACCESS_KEY${NC}   → Your secret access key"
        echo ""
        echo "  3. Push to main — GitHub Actions will auto-deploy"
        echo ""
        return
    fi

    # Check gh auth status
    if ! gh auth status &>/dev/null; then
        info "GitHub CLI not authenticated — skipping automated setup"
        echo ""
        echo "  Run 'gh auth login' first, then re-run this script"
        echo "  Or set secrets manually at:"
        echo "  https://github.com/${GITHUB_REPO}/settings/secrets/actions"
        echo ""
        return
    fi

    success "GitHub CLI authenticated"

    if ! confirm "Set up GitHub Actions secrets for CI/CD?"; then
        info "Skipping GitHub Actions setup"
        return
    fi

    echo ""
    echo -e "  ${YELLOW}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${YELLOW}║${NC}  ${BOLD}MANUAL INPUT REQUIRED${NC}                                ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}                                                       ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}  This script does NOT store or read secrets.           ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}  You'll paste them directly into gh CLI prompts.       ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Set AWS_ACCESS_KEY_ID
    echo -ne "  ${YELLOW}?${NC}  Paste your ${BOLD}AWS_ACCESS_KEY_ID${NC}: "
    read -r aws_key_id
    if [[ -n "$aws_key_id" ]]; then
        if echo "$aws_key_id" | gh secret set AWS_ACCESS_KEY_ID --repo "$GITHUB_REPO" 2>/dev/null; then
            success "Set GitHub secret: AWS_ACCESS_KEY_ID"
        else
            fail "Failed to set AWS_ACCESS_KEY_ID"
        fi
    else
        warn "Skipped AWS_ACCESS_KEY_ID (empty)"
    fi

    # Set AWS_SECRET_ACCESS_KEY
    echo -ne "  ${YELLOW}?${NC}  Paste your ${BOLD}AWS_SECRET_ACCESS_KEY${NC}: "
    read -rs aws_secret_key
    echo ""
    if [[ -n "$aws_secret_key" ]]; then
        if echo "$aws_secret_key" | gh secret set AWS_SECRET_ACCESS_KEY --repo "$GITHUB_REPO" 2>/dev/null; then
            success "Set GitHub secret: AWS_SECRET_ACCESS_KEY"
        else
            fail "Failed to set AWS_SECRET_ACCESS_KEY"
        fi
    else
        warn "Skipped AWS_SECRET_ACCESS_KEY (empty)"
    fi

    # Verify workflow file exists
    if [[ -f "${SCRIPT_DIR}/.github/workflows/deploy.yml" ]]; then
        success "GitHub Actions workflow found: .github/workflows/deploy.yml"
        info "CI/CD will auto-deploy on push to main"
    else
        warn "deploy.yml not found — CI/CD won't trigger until you push the workflow"
    fi
}

# ─── STEP 14: Smoke Test ─────────────────────────────────────────────

smoke_test() {
    step_header "Smoke Test"

    info "Running end-to-end verification..."

    # Test 1: CloudFront returns 200
    info "Testing CloudFront endpoint..."
    local cf_status
    cf_status=$(curl -s -o /dev/null -w "%{http_code}" "${CF_URL}/" 2>/dev/null || echo "000")
    if [[ "$cf_status" == "200" ]]; then
        success "CloudFront responds: HTTP ${cf_status}"
    elif [[ "$cf_status" == "403" ]]; then
        warn "CloudFront returned 403 — geo-restriction may be blocking your IP (IL only)"
        detail "This is expected if you are outside Israel"
    elif [[ "$cf_status" == "000" ]]; then
        warn "Could not reach CloudFront — distribution may still be deploying (takes ~5 min)"
        detail "URL: ${CF_URL}"
    else
        warn "CloudFront returned HTTP ${cf_status}"
    fi

    # Test 2: API Gateway health (OPTIONS should return 200)
    info "Testing API Gateway endpoint..."
    local api_status
    api_status=$(curl -s -o /dev/null -w "%{http_code}" -X OPTIONS "${API_URL}/apply" 2>/dev/null || echo "000")
    if [[ "$api_status" == "200" ]]; then
        success "API Gateway responds: HTTP ${api_status}"
    elif [[ "$api_status" == "000" ]]; then
        warn "Could not reach API Gateway"
        detail "URL: ${API_URL}/apply"
    else
        warn "API Gateway returned HTTP ${api_status}"
    fi

    # Test 3: Lambda invocation (send a test payload)
    info "Testing Lambda with a dummy POST..."
    local lambda_response
    lambda_response=$(curl -s -X POST "${API_URL}/apply" \
        -H "Content-Type: application/json" \
        -d '{"name":"deploy-test","email":"test@deploy.local","github":"test-deploy","project_idea":"Automated deploy test — safe to delete"}' \
        2>/dev/null || echo "")
    if echo "$lambda_response" | grep -q '"message"'; then
        success "Lambda responded successfully"
        local test_app_id
        test_app_id=$(echo "$lambda_response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
        if [[ -n "$test_app_id" ]]; then
            detail "Test application ID: ${test_app_id}"
            detail "Clean up later: aws dynamodb delete-item --table-name ${DYNAMO_TABLE} --key '{\"id\":{\"S\":\"${test_app_id}\"}}' --profile ${AWS_PROFILE_NAME} --region ${REGION}"
        fi
    elif echo "$lambda_response" | grep -q '"error"'; then
        warn "Lambda returned an error"
        detail "Response: ${lambda_response}"
    else
        warn "Could not verify Lambda response"
        detail "Response: ${lambda_response}"
    fi

    # Test 4: DynamoDB table is accessible
    info "Testing DynamoDB access..."
    local scan_result
    scan_result=$(aws dynamodb scan \
        --table-name "$DYNAMO_TABLE" \
        --profile "$AWS_PROFILE_NAME" \
        --region "$REGION" \
        --select COUNT \
        --max-items 1 2>/dev/null || echo "")
    if echo "$scan_result" | grep -q '"Count"'; then
        local item_count
        item_count=$(echo "$scan_result" | grep -o '"Count": [0-9]*' | grep -o '[0-9]*')
        success "DynamoDB accessible — ${item_count} item(s) in table"
    else
        warn "Could not query DynamoDB"
    fi
}

# ─── Summary ──────────────────────────────────────────────────────────

print_summary() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${BOLD}DEPLOYMENT SUMMARY${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "  ${GREEN}Passed:${NC}  ${PASS}"
    echo -e "  ${RED}Failed:${NC}  ${FAIL}"
    echo -e "  ${DIM}Skipped:${NC} ${SKIP}"
    echo ""

    echo -e "  ${BOLD}Resources:${NC}"
    echo -e "  ────────────────────────────────────────────────────────"
    if [[ -n "${CF_URL:-}" ]]; then
        echo -e "  ${BOLD}Site URL:${NC}       ${CYAN}${CF_URL}${NC}"
    fi
    if [[ -n "${API_URL:-}" ]]; then
        echo -e "  ${BOLD}API URL:${NC}        ${API_URL}"
    fi
    if [[ -n "${BUCKET_NAME:-}" ]]; then
        echo -e "  ${BOLD}S3 Bucket:${NC}      ${BUCKET_NAME}"
    fi
    if [[ -n "${CF_DIST_ID:-}" ]]; then
        echo -e "  ${BOLD}CloudFront ID:${NC}  ${CF_DIST_ID}"
    fi
    echo -e "  ${BOLD}DynamoDB:${NC}       ${DYNAMO_TABLE}"
    echo -e "  ${BOLD}Lambda:${NC}         ${LAMBDA_NAME}"
    echo -e "  ${BOLD}Region:${NC}         ${REGION}"
    echo -e "  ${BOLD}AWS Profile:${NC}    ${AWS_PROFILE_NAME}"
    echo ""

    echo -e "  ${BOLD}Useful Commands:${NC}"
    echo -e "  ────────────────────────────────────────────────────────"
    echo -e "  ${DIM}# View applications${NC}"
    echo -e "  aws dynamodb scan --table-name ${DYNAMO_TABLE} --profile ${AWS_PROFILE_NAME} --region ${REGION}"
    echo ""
    echo -e "  ${DIM}# Redeploy site files${NC}"
    echo -e "  bash deploy.sh"
    echo ""
    echo -e "  ${DIM}# Update infrastructure${NC}"
    echo -e "  cd terraform && terraform plan && terraform apply"
    echo ""
    echo -e "  ${DIM}# Invalidate CDN cache${NC}"
    echo -e "  aws cloudfront create-invalidation --profile ${AWS_PROFILE_NAME} --distribution-id ${CF_DIST_ID:-???} --paths '/*'"
    echo ""

    if [[ $FAIL -gt 0 ]]; then
        echo -e "  ${YELLOW}⚠  Some steps had failures. Review the output above.${NC}"
        echo -e "  ${YELLOW}   Re-run this script to retry failed steps.${NC}"
    else
        echo -e "  ${GREEN}Deploy complete! 🎉${NC}"
    fi
    echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────

main() {
    banner

    echo -e "  ${DIM}This wizard will provision the full AWS stack for the"
    echo -e "  digi-dan oss community join site. It is safe to re-run —"
    echo -e "  existing resources will be detected and skipped/updated.${NC}"
    echo ""
    echo -e "  ${BOLD}What will be created:${NC}"
    echo -e "    • S3 bucket (static site, private via CloudFront)"
    echo -e "    • CloudFront distribution (Israel-only geo-restriction)"
    echo -e "    • API Gateway HTTP API (POST /apply)"
    echo -e "    • Lambda function (Node.js 20, form handler)"
    echo -e "    • DynamoDB table (application storage)"
    echo -e "    • SES email verification (admin notifications)"
    echo -e "    • Terraform remote state bucket"
    echo ""

    if ! confirm "Ready to begin?"; then
        echo ""
        info "Cancelled. Re-run when ready."
        exit 0
    fi

    check_prerequisites         # Step 1
    verify_aws_credentials      # Step 2
    check_existing_resources    # Step 3
    check_terraform_state       # Step 4
    terraform_init              # Step 5
    terraform_plan              # Step 6
    terraform_apply             # Step 7
    read_outputs                # Step 8
    upload_site_files           # Step 9
    invalidate_cloudfront       # Step 10
    verify_ses_email            # Step 11
    setup_remote_state          # Step 12

    # Bonus: GitHub Actions setup
    STEP=$((STEP + 1))
    TOTAL_STEPS=$((TOTAL_STEPS + 1))
    setup_github_actions

    # Bonus: Smoke test
    STEP=$((STEP + 1))
    TOTAL_STEPS=$((TOTAL_STEPS + 1))
    smoke_test

    # Adjust total to match actual
    TOTAL_STEPS=$STEP

    print_summary
}

main "$@"
