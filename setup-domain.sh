#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  digi-dan oss — Domain Setup Wizard                                ║
# ║  Connects digi-dan.com + www to the CloudFront distribution        ║
# ║  Safe to re-run: Terraform manages state idempotently              ║
# ╚══════════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ─── Constants & Config ──────────────────────────────────────────────
DOMAIN_NAME="digi-dan.com"
REGION="il-central-1"
AWS_PROFILE_NAME="digi-dan"
TF_DIR="terraform"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export AWS_PROFILE="$AWS_PROFILE_NAME"

# ─── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Counters ────────────────────────────────────────────────────────
STEP=0
TOTAL_STEPS=8
PASS=0
FAIL=0

# ─── Helper Functions ────────────────────────────────────────────────

banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}digi-dan oss${NC} — Domain Setup Wizard                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${DIM}Connect ${DOMAIN_NAME} + www to CloudFront${NC}                  ${CYAN}║${NC}"
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

# ─── STEP 1: Pre-flight Checks ──────────────────────────────────────

step_01_preflight() {
    step_header "Pre-flight Checks"

    local missing=0

    # AWS CLI
    if command -v aws &>/dev/null; then
        success "AWS CLI found: $(aws --version 2>&1 | head -1)"
    else
        fail "AWS CLI not found"
        detail "Install: https://awscli.amazonaws.com/AWSCLIV2.msi"
        missing=1
    fi

    # Terraform
    if command -v terraform &>/dev/null; then
        success "Terraform found: $(terraform --version 2>&1 | head -1)"
    else
        fail "Terraform not found"
        detail "Install: winget install Hashicorp.Terraform"
        missing=1
    fi

    # dig (optional — for DNS verification)
    if command -v dig &>/dev/null; then
        success "dig found (DNS verification available)"
    else
        warn "dig not found — DNS verification will be skipped"
        detail "Install: sudo apt install dnsutils"
    fi

    # curl (for smoke test)
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
    if identity=$(aws sts get-caller-identity --profile "$AWS_PROFILE_NAME" 2>&1); then
        local account_id arn
        account_id=$(echo "$identity" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
        arn=$(echo "$identity" | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)
        success "Authenticated to AWS"
        detail "Account: ${account_id}"
        detail "User:    ${arn}"
    else
        abort "AWS credentials not configured. Run: aws configure --profile ${AWS_PROFILE_NAME}"
    fi

    # Check Terraform files exist
    if [[ -f "${SCRIPT_DIR}/${TF_DIR}/dns.tf" ]]; then
        success "Found: ${TF_DIR}/dns.tf"
    else
        abort "Missing: ${TF_DIR}/dns.tf — run the Terraform setup first"
    fi

    success "All pre-flight checks passed"
}

# ─── STEP 2: Verify Route 53 Hosted Zone ────────────────────────────

step_02_verify_hosted_zone() {
    step_header "Verify Route 53 Hosted Zone (${DOMAIN_NAME})"

    info "Looking for Route 53 hosted zone..."

    local hosted_zones
    hosted_zones=$(aws route53 list-hosted-zones-by-name \
        --dns-name "${DOMAIN_NAME}" \
        --max-items 1 \
        --profile "$AWS_PROFILE_NAME" 2>/dev/null || echo "")

    ZONE_ID=""

    if echo "$hosted_zones" | grep -q "\"Name\": \"${DOMAIN_NAME}.\""; then
        ZONE_ID=$(echo "$hosted_zones" | grep -o '"Id": "/hostedzone/[^"]*"' | head -1 | sed 's|.*/hostedzone/||;s|"||g')
        success "Hosted zone found: ${ZONE_ID}"

        # Check nameservers
        info "Checking nameservers..."
        local zone_detail
        zone_detail=$(aws route53 get-hosted-zone \
            --id "$ZONE_ID" \
            --profile "$AWS_PROFILE_NAME" 2>/dev/null || echo "")

        if echo "$zone_detail" | grep -q "NameServers"; then
            success "Nameservers configured in Route 53"

            # Show the nameservers
            local ns_list
            ns_list=$(echo "$zone_detail" | grep -A 10 '"NameServers"' | grep '"ns-' | sed 's/[",]//g' | xargs)
            detail "NS: ${ns_list}"

            # Check if domain is registered in Route 53 (nameservers auto-correct)
            local r53_domains
            r53_domains=$(aws route53domains list-domains \
                --region us-east-1 \
                --profile "$AWS_PROFILE_NAME" 2>/dev/null || echo "")
            if echo "$r53_domains" | grep -q "${DOMAIN_NAME}"; then
                success "Domain registered in Route 53 — nameservers are automatic"
            elif command -v dig &>/dev/null; then
                # Verify delegation with dig for externally-registered domains
                info "Verifying DNS delegation..."
                local actual_ns
                actual_ns=$(dig NS "${DOMAIN_NAME}" +short 2>/dev/null || echo "")
                if [[ -n "$actual_ns" ]]; then
                    success "DNS delegation confirmed"
                    detail "Resolving NS: $(echo "$actual_ns" | tr '\n' ' ')"
                else
                    warn "Could not verify DNS delegation — nameservers may not be propagated yet"
                    detail "Ensure your domain registrar points to the Route 53 nameservers above"
                fi
            fi
        fi
    else
        warn "Route 53 hosted zone for '${DOMAIN_NAME}' not found"

        if confirm "Create hosted zone for ${DOMAIN_NAME} now?"; then
            info "Creating Route 53 hosted zone..."
            local create_output
            local create_exit=0
            create_output=$(aws route53 create-hosted-zone \
                --name "${DOMAIN_NAME}" \
                --caller-reference "setup-domain-$(date +%s)" \
                --profile "$AWS_PROFILE_NAME" 2>&1) || create_exit=$?

            if [[ $create_exit -eq 0 ]]; then
                ZONE_ID=$(echo "$create_output" | grep -o '"Id": "/hostedzone/[^"]*"' | head -1 | sed 's|.*/hostedzone/||;s|"||g')
                success "Hosted zone created: ${ZONE_ID}"

                # Extract nameservers from create output
                local ns_list
                ns_list=$(echo "$create_output" | grep -A 10 '"NameServers"' | grep '"ns-' | sed 's/[",]//g' | xargs)

                # Check if domain is registered in Route 53 — auto-update nameservers
                local r53_domains
                r53_domains=$(aws route53domains list-domains \
                    --region us-east-1 \
                    --profile "$AWS_PROFILE_NAME" 2>/dev/null || echo "")

                if echo "$r53_domains" | grep -q "${DOMAIN_NAME}"; then
                    info "Domain registered in Route 53 — updating nameservers automatically..."
                    local ns_args=""
                    for ns in $ns_list; do
                        ns_args="${ns_args} Name=${ns}"
                    done
                    local update_exit=0
                    aws route53domains update-domain-nameservers \
                        --region us-east-1 \
                        --profile "$AWS_PROFILE_NAME" \
                        --domain-name "${DOMAIN_NAME}" \
                        --nameservers $ns_args 2>&1 || update_exit=$?

                    if [[ $update_exit -eq 0 ]]; then
                        success "Nameservers updated automatically"
                        for ns in $ns_list; do
                            detail "${ns}"
                        done
                    else
                        warn "Auto-update failed — update nameservers manually"
                    fi
                else
                    # External registrar — show manual instructions
                    echo ""
                    echo -e "  ${YELLOW}╔═══════════════════════════════════════════════════════════╗${NC}"
                    echo -e "  ${YELLOW}║${NC}  ${BOLD}ACTION REQUIRED${NC}                                         ${YELLOW}║${NC}"
                    echo -e "  ${YELLOW}║${NC}                                                           ${YELLOW}║${NC}"
                    echo -e "  ${YELLOW}║${NC}  Update your domain registrar's nameservers to:            ${YELLOW}║${NC}"
                    for ns in $ns_list; do
                    echo -e "  ${YELLOW}║${NC}    ${CYAN}${ns}${NC}"
                    done
                    echo -e "  ${YELLOW}║${NC}                                                           ${YELLOW}║${NC}"
                    echo -e "  ${YELLOW}║${NC}  ${DIM}Without this, certificate validation will hang.${NC}          ${YELLOW}║${NC}"
                    echo -e "  ${YELLOW}╚═══════════════════════════════════════════════════════════╝${NC}"
                    echo ""
                    wait_for_user "Update your registrar nameservers, then press Enter..."
                fi
            else
                fail "Failed to create hosted zone"
                echo "$create_output"
                abort "Create the hosted zone manually in the AWS Console and re-run."
            fi
        else
            abort "Hosted zone required. Create it and re-run this script."
        fi
    fi

    # Validate zone_id
    if [[ -z "$ZONE_ID" ]]; then
        abort "Could not determine hosted zone ID"
    fi
}

# ─── STEP 3: Check IAM Permissions ──────────────────────────────────

step_03_check_iam_permissions() {
    step_header "Check IAM Permissions (ACM + Route 53)"

    echo ""
    echo -e "  ${YELLOW}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${YELLOW}║${NC}  ${BOLD}ACTION REQUIRED${NC}                                         ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}                                                           ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}  Update the deploy IAM policy in the AWS Console with      ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}  the ACM and Route 53 permissions from:                    ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}                                                           ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}    ${CYAN}iam/policies/iam-policy-deploy.json${NC}                    ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}                                                           ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}  New statements needed:                                    ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}    • ACMCertificates (acm:Request/Describe/List/Get)        ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}    • Route53Read (route53:Get/List)                          ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}║${NC}    • Route53ManageRecords (route53:ChangeResourceRecordSets) ${YELLOW}║${NC}"
    echo -e "  ${YELLOW}╚═══════════════════════════════════════════════════════════╝${NC}"

    wait_for_user "Press Enter when you've updated the IAM policy..."

    # Validate: try an ACM list to check permissions
    info "Validating ACM permissions (us-east-1)..."
    if aws acm list-certificates --region us-east-1 --profile "$AWS_PROFILE_NAME" &>/dev/null; then
        success "ACM permissions verified"
    else
        fail "ACM permissions missing — update the deploy policy"
        detail "The policy needs: acm:ListCertificates with Resource: \"*\""
        abort "Update the IAM policy and re-run."
    fi

    # Validate: try a Route 53 list
    info "Validating Route 53 permissions..."
    if aws route53 list-hosted-zones --profile "$AWS_PROFILE_NAME" &>/dev/null; then
        success "Route 53 permissions verified"
    else
        fail "Route 53 permissions missing — update the deploy policy"
        detail "The policy needs: route53:ListHostedZones with Resource: \"*\""
        abort "Update the IAM policy and re-run."
    fi

    success "IAM permissions check passed"
}

# ─── STEP 4: Terraform Init ─────────────────────────────────────────

step_04_terraform_init() {
    step_header "Terraform Init"

    cd "${SCRIPT_DIR}/${TF_DIR}"

    info "Initializing Terraform (picks up new us-east-1 provider)..."
    echo ""

    if terraform init -input=false; then
        echo ""
        success "Terraform initialized"
    else
        echo ""
        abort "Terraform init failed. Check the errors above."
    fi

    cd "${SCRIPT_DIR}"
}

# ─── STEP 5: Terraform Plan + Apply ─────────────────────────────────

step_05_terraform_apply() {
    step_header "Terraform Plan + Apply"

    cd "${SCRIPT_DIR}/${TF_DIR}"

    # Plan
    info "Running terraform plan..."
    echo ""

    if terraform plan -input=false -out=domain.tfplan; then
        echo ""
        success "Plan generated"
    else
        echo ""
        abort "Terraform plan failed. Check the errors above."
    fi

    cd "${SCRIPT_DIR}"

    if ! confirm "Review the plan above. Apply these changes?"; then
        rm -f "${SCRIPT_DIR}/${TF_DIR}/domain.tfplan"
        info "Cancelled. Re-run when ready."
        exit 0
    fi

    cd "${SCRIPT_DIR}/${TF_DIR}"

    # Apply
    info "Applying Terraform changes..."
    info "Certificate validation: ~2-5 min | CloudFront update: ~3-5 min"
    echo ""

    if terraform apply -input=false domain.tfplan; then
        echo ""
        success "Terraform apply completed"
    else
        echo ""
        fail "Terraform apply had errors"
        warn "Some resources may have been partially created."
        warn "This is safe — re-run this script to retry."
        warn "Terraform tracks state and will pick up where it left off."
        echo ""
        if ! confirm "Try continuing to read outputs anyway?"; then
            rm -f domain.tfplan
            cd "${SCRIPT_DIR}"
            abort "Fix the errors and re-run this script."
        fi
    fi

    rm -f domain.tfplan
    cd "${SCRIPT_DIR}"
}

# ─── STEP 6: Read Outputs + Verify DNS ──────────────────────────────

step_06_read_outputs() {
    step_header "Read Outputs + Verify DNS"

    cd "${SCRIPT_DIR}/${TF_DIR}"

    SITE_URL=""
    CERT_ARN=""
    CF_URL=""

    if SITE_URL=$(terraform output -raw site_url 2>/dev/null); then
        success "Site URL:        ${SITE_URL}"
    else
        fail "Could not read site_url output"
    fi

    if CERT_ARN=$(terraform output -raw certificate_arn 2>/dev/null); then
        success "Certificate:     ${CERT_ARN}"
    else
        fail "Could not read certificate_arn output"
    fi

    if CF_URL=$(terraform output -raw cloudfront_url 2>/dev/null); then
        success "CloudFront URL:  ${CF_URL}"
    else
        fail "Could not read cloudfront_url output"
    fi

    cd "${SCRIPT_DIR}"

    # Optional DNS check
    if command -v dig &>/dev/null; then
        info "Verifying DNS records..."

        local apex_result
        apex_result=$(dig A "${DOMAIN_NAME}" +short 2>/dev/null || echo "")
        if [[ -n "$apex_result" ]]; then
            success "DNS A record for ${DOMAIN_NAME} resolves"
            detail "→ ${apex_result}"
        else
            warn "DNS A record for ${DOMAIN_NAME} not resolving yet"
            detail "DNS propagation can take up to 48 hours"
        fi

        local www_result
        www_result=$(dig A "www.${DOMAIN_NAME}" +short 2>/dev/null || echo "")
        if [[ -n "$www_result" ]]; then
            success "DNS A record for www.${DOMAIN_NAME} resolves"
            detail "→ ${www_result}"
        else
            warn "DNS A record for www.${DOMAIN_NAME} not resolving yet"
        fi
    fi

    if [[ -z "$SITE_URL" ]]; then
        abort "Missing critical outputs. Run 'cd terraform && terraform output' to debug."
    fi
}

# ─── STEP 7: Re-deploy Site Files ────────────────────────────────────

step_07_redeploy_site() {
    step_header "Re-deploy Site Files (canonical link update)"

    cd "${SCRIPT_DIR}"

    local cf_dist_id
    cf_dist_id=$(cd "${TF_DIR}" && terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
    local bucket_name
    bucket_name=$(cd "${TF_DIR}" && terraform output -raw s3_bucket_name 2>/dev/null || echo "")

    if [[ -z "$bucket_name" ]]; then
        fail "Could not read S3 bucket name from Terraform outputs"
        return
    fi

    # Upload index.html (has the new canonical link)
    info "Uploading index.html to S3..."
    if aws s3 cp index.html "s3://${bucket_name}/index.html" \
        --profile "$AWS_PROFILE_NAME" \
        --content-type "text/html; charset=utf-8" \
        --region "$REGION"; then
        success "Uploaded: index.html"
    else
        fail "Failed to upload index.html"
    fi

    # Invalidate CloudFront cache
    if [[ -n "$cf_dist_id" ]]; then
        info "Invalidating CloudFront cache..."
        local inv_output
        if inv_output=$(aws cloudfront create-invalidation \
            --profile "$AWS_PROFILE_NAME" \
            --distribution-id "$cf_dist_id" \
            --paths "/*" 2>&1); then
            local inv_id
            inv_id=$(echo "$inv_output" | grep -o '"Id": "[^"]*"' | head -1 | cut -d'"' -f4)
            success "Cache invalidation created: ${inv_id}"
            detail "Propagation takes 1-2 minutes"
        else
            warn "CloudFront invalidation failed — you can do it manually later"
        fi
    else
        warn "Could not read CloudFront distribution ID — skip invalidation"
    fi
}

# ─── STEP 8: Smoke Test ─────────────────────────────────────────────

step_08_smoke_test() {
    step_header "Smoke Test"

    if ! command -v curl &>/dev/null; then
        warn "curl not available — skipping smoke test"
        return
    fi

    info "Testing https://${DOMAIN_NAME}/ ..."
    local apex_status
    apex_status=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN_NAME}/" 2>/dev/null || echo "000")
    if [[ "$apex_status" == "200" ]]; then
        success "${DOMAIN_NAME} responds: HTTP ${apex_status}"
    elif [[ "$apex_status" == "403" ]]; then
        warn "${DOMAIN_NAME} returned 403 — geo-restriction (Israel only)"
        detail "This is expected if you are outside Israel"
    elif [[ "$apex_status" == "000" ]]; then
        warn "Could not reach ${DOMAIN_NAME} — DNS may not have propagated yet"
        detail "DNS propagation can take up to 48 hours"
        detail "The CloudFront URL still works: ${CF_URL:-<check terraform output>}"
    else
        warn "${DOMAIN_NAME} returned HTTP ${apex_status}"
    fi

    info "Testing https://www.${DOMAIN_NAME}/ ..."
    local www_status
    www_status=$(curl -s -o /dev/null -w "%{http_code}" "https://www.${DOMAIN_NAME}/" 2>/dev/null || echo "000")
    if [[ "$www_status" == "200" ]]; then
        success "www.${DOMAIN_NAME} responds: HTTP ${www_status}"
    elif [[ "$www_status" == "403" ]]; then
        warn "www.${DOMAIN_NAME} returned 403 — geo-restriction (Israel only)"
    elif [[ "$www_status" == "000" ]]; then
        warn "Could not reach www.${DOMAIN_NAME}"
    else
        warn "www.${DOMAIN_NAME} returned HTTP ${www_status}"
    fi
}

# ─── Summary ─────────────────────────────────────────────────────────

print_summary() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                  ${BOLD}DOMAIN SETUP SUMMARY${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "  ${GREEN}Passed:${NC}  ${PASS}"
    echo -e "  ${RED}Failed:${NC}  ${FAIL}"
    echo ""

    echo -e "  ${BOLD}Domain:${NC}"
    echo -e "  ────────────────────────────────────────────────────────"
    echo -e "  ${BOLD}Primary URL:${NC}     ${CYAN}https://${DOMAIN_NAME}${NC}"
    echo -e "  ${BOLD}WWW URL:${NC}         ${CYAN}https://www.${DOMAIN_NAME}${NC}"
    if [[ -n "${CF_URL:-}" ]]; then
        echo -e "  ${BOLD}CloudFront URL:${NC}  ${CF_URL}"
    fi
    if [[ -n "${CERT_ARN:-}" ]]; then
        echo -e "  ${BOLD}Certificate:${NC}     ${CERT_ARN}"
    fi
    echo ""

    echo -e "  ${BOLD}Post-Setup:${NC}"
    echo -e "  ────────────────────────────────────────────────────────"
    echo -e "  ${DIM}Remove the temporary setup-domain policy from digi-dan-deployer${NC}"
    echo -e "  ${DIM}in the AWS Console (it is no longer needed).${NC}"
    echo ""

    if [[ $FAIL -gt 0 ]]; then
        echo -e "  ${YELLOW}⚠  Some steps had issues. Review the output above.${NC}"
        echo -e "  ${YELLOW}   Re-run this script to retry — it is safe to re-run.${NC}"
    else
        echo -e "  ${GREEN}Domain setup complete!${NC}"
    fi
    echo ""
}

# ─── Main ────────────────────────────────────────────────────────────

main() {
    banner

    echo -e "  ${DIM}This wizard connects ${DOMAIN_NAME} to your CloudFront"
    echo -e "  distribution. It creates an ACM certificate, DNS validation"
    echo -e "  records, and A alias records via Terraform.${NC}"
    echo ""
    echo -e "  ${BOLD}What will be configured:${NC}"
    echo -e "    • ACM certificate (us-east-1) for ${DOMAIN_NAME} + www"
    echo -e "    • DNS validation records in Route 53"
    echo -e "    • A alias records: ${DOMAIN_NAME} → CloudFront"
    echo -e "    • A alias records: www.${DOMAIN_NAME} → CloudFront"
    echo -e "    • CloudFront aliases + TLS certificate"
    echo -e "    • CORS tightened to ${DOMAIN_NAME} origins only"
    echo ""

    if ! confirm "Ready to begin?"; then
        echo ""
        info "Cancelled. Re-run when ready."
        exit 0
    fi

    step_01_preflight
    step_02_verify_hosted_zone
    step_03_check_iam_permissions
    step_04_terraform_init
    step_05_terraform_apply
    step_06_read_outputs
    step_07_redeploy_site
    step_08_smoke_test
    print_summary
}

main "$@"
