#!/usr/bin/env bash
# ─── One-time Terraform import of existing AWS resources ───
# Run from repo root: bash scripts/tf-import.sh [--profile PROFILE_NAME] (default: digi-dan)
# Requires: aws cli configured, terraform installed
set -uo pipefail

REGION="il-central-1"
REGION_US="us-east-1"
TF_DIR="terraform"
STATE_BUCKET="digi-dan-oss-tfstate"
DOMAIN="digi-dan.com"
ZONE_ID="Z0431444POY83AEC44M1"

# ─── AWS profile ───
AWS_PROFILE_NAME="${1:-digi-dan}"
if [ "${1:-}" = "--profile" ] && [ -n "${2:-}" ]; then
  AWS_PROFILE_NAME="$2"
fi
AWS_ARGS="--profile $AWS_PROFILE_NAME"
export AWS_PROFILE="$AWS_PROFILE_NAME"
echo "Using AWS profile: $AWS_PROFILE_NAME"

aws_cmd() {
  aws $AWS_ARGS "$@"
}

ERRORS=0
IMPORTED=0
SKIPPED=0

echo "=== digi-dan-oss: Terraform State Import ==="
echo ""

# ─── Pre-flight: verify AWS access ───
echo "[0/5] Verifying AWS credentials..."
if ! CALLER_IDENTITY=$(aws_cmd sts get-caller-identity --region "$REGION" --output json 2>&1); then
  echo "  ERROR: AWS credentials not configured or expired."
  echo "  Run 'aws configure' or pass --profile: bash scripts/tf-import.sh --profile myprofile"
  exit 1
fi
ACCOUNT_ID=$(echo "$CALLER_IDENTITY" | python3 -c "import sys,json; print(json.load(sys.stdin)['Account'])" 2>/dev/null || \
  aws_cmd sts get-caller-identity --query "Account" --output text --region "$REGION")
USER_ARN=$(echo "$CALLER_IDENTITY" | python3 -c "import sys,json; print(json.load(sys.stdin)['Arn'])" 2>/dev/null || echo "unknown")
echo "  Account: $ACCOUNT_ID"
echo "  Identity: $USER_ARN"
echo ""
echo "  Ensure iam/policies/iam-policy-deploy.json is attached to this IAM identity."
echo "  Without it, bucket creation and resource discovery will fail."
echo ""

# ─── Step 1: Ensure state bucket exists ───
echo "[1/5] Ensuring state bucket exists..."
HEAD_RESULT=$(aws_cmd s3api head-bucket --bucket "$STATE_BUCKET" --region "$REGION" 2>&1) && BUCKET_EXISTS=true || BUCKET_EXISTS=false

if $BUCKET_EXISTS; then
  echo "  State bucket already exists."
else
  echo "  State bucket not accessible. Attempting to create..."
  if aws_cmd s3api create-bucket --bucket "$STATE_BUCKET" --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" 2>&1; then
    aws_cmd s3api put-bucket-versioning --bucket "$STATE_BUCKET" --region "$REGION" \
      --versioning-configuration Status=Enabled 2>/dev/null || true
    echo "  State bucket created."
  else
    echo ""
    echo "  ERROR: Cannot create state bucket '$STATE_BUCKET'."
    echo "  Your IAM user likely lacks s3:CreateBucket permission."
    echo ""
    echo "  Please create the bucket manually:"
    echo "    Option A — AWS Console:"
    echo "      1. Go to S3 in region $REGION"
    echo "      2. Create bucket named: $STATE_BUCKET"
    echo "      3. Enable Versioning"
    echo ""
    echo "    Option B — AWS CLI (with admin/elevated credentials):"
    echo "      aws s3api create-bucket --bucket $STATE_BUCKET --region $REGION \\"
    echo "        --create-bucket-configuration LocationConstraint=$REGION"
    echo ""
    read -r -p "  Press Enter once the bucket exists (or Ctrl+C to abort)... "

    if ! aws_cmd s3api head-bucket --bucket "$STATE_BUCKET" --region "$REGION" 2>/dev/null; then
      echo "  ERROR: Still cannot access bucket '$STATE_BUCKET'. Aborting."
      exit 1
    fi
    echo "  State bucket confirmed."
  fi
fi

# ─── Step 2: Terraform init ───
echo ""
echo "[2/5] Running terraform init..."
cd "$TF_DIR"
echo "yes" | terraform init -migrate-state
echo ""

# ─── Step 3: Discover resource IDs ───
echo "[3/5] Discovering existing AWS resource IDs..."
echo ""

# S3
BUCKET="digi-dan-oss-join-site"
if aws_cmd s3api head-bucket --bucket "$BUCKET" --region "$REGION" 2>/dev/null; then
  echo "  S3 bucket: $BUCKET"
else
  echo "  S3 bucket: NOT FOUND (will be created by terraform)"
  BUCKET=""
fi

# DynamoDB
TABLE="community-applications"
if aws_cmd dynamodb describe-table --table-name "$TABLE" --region "$REGION" > /dev/null 2>&1; then
  echo "  DynamoDB table: $TABLE"
else
  echo "  DynamoDB table: NOT FOUND (will be created by terraform)"
  TABLE=""
fi

# Lambda
LAMBDA="digi-dan-oss-join-apply"
if aws_cmd lambda get-function --function-name "$LAMBDA" --region "$REGION" > /dev/null 2>&1; then
  echo "  Lambda function: $LAMBDA"
else
  echo "  Lambda function: NOT FOUND (will be created by terraform)"
  LAMBDA=""
fi

# Lambda permission — check only if Lambda exists
LAMBDA_PERM=""
if [ -n "$LAMBDA" ]; then
  if aws_cmd lambda get-policy --function-name "$LAMBDA" --region "$REGION" 2>/dev/null | grep -q "AllowAPIGateway"; then
    LAMBDA_PERM="${LAMBDA}/AllowAPIGateway"
    echo "  Lambda permission: AllowAPIGateway"
  else
    echo "  Lambda permission: NOT FOUND (will be created by terraform)"
  fi
fi

# CloudFront OAC
OAC_ID=$(aws_cmd cloudfront list-origin-access-controls --region "$REGION_US" \
  --query "OriginAccessControlList.Items[?Name=='digi-dan-oss-oac'].Id | [0]" --output text 2>/dev/null || echo "")
[ "$OAC_ID" = "None" ] && OAC_ID=""
echo "  CloudFront OAC: ${OAC_ID:-NOT FOUND}"

# CloudFront Distribution — find by alias
DIST_ID=$(aws_cmd cloudfront list-distributions --region "$REGION_US" \
  --query "DistributionList.Items[?contains(Aliases.Items, '$DOMAIN')].Id | [0]" --output text 2>/dev/null || echo "")
[ "$DIST_ID" = "None" ] && DIST_ID=""
echo "  CloudFront Distribution: ${DIST_ID:-NOT FOUND}"

# API Gateway — may have duplicates from failed deploy
ALL_API_IDS=$(aws_cmd apigatewayv2 get-apis --region "$REGION" \
  --query "Items[?Name=='digi-dan-oss-join-api'].ApiId" --output text 2>/dev/null || echo "")
API_COUNT=$(echo "$ALL_API_IDS" | wc -w | tr -d ' ')
API_ID=""
if [ "$API_COUNT" -gt 1 ]; then
  echo ""
  echo "  WARNING: Found $API_COUNT API Gateways named 'digi-dan-oss-join-api'."
  echo "  IDs: $ALL_API_IDS"
  echo "  Picking the one with a Lambda integration..."
  for candidate in $ALL_API_IDS; do
    HAS_INTEGRATION=$(aws_cmd apigatewayv2 get-integrations --api-id "$candidate" --region "$REGION" \
      --query "length(Items)" --output text 2>/dev/null || echo "0")
    if [ "$HAS_INTEGRATION" != "0" ]; then
      API_ID="$candidate"
      break
    fi
  done
  if [ -z "$API_ID" ]; then
    API_ID=$(echo "$ALL_API_IDS" | awk '{print $1}')
  fi
  echo "  Selected: $API_ID"
  echo "  After import succeeds, manually delete unused API Gateways from the AWS console."
elif [ "$API_COUNT" -eq 1 ]; then
  API_ID="$ALL_API_IDS"
fi
[ "$API_ID" = "None" ] && API_ID=""
echo "  API Gateway: ${API_ID:-NOT FOUND}"

# API Gateway integration + route
INTEGRATION_ID=""
ROUTE_ID=""
if [ -n "$API_ID" ]; then
  INTEGRATION_ID=$(aws_cmd apigatewayv2 get-integrations --api-id "$API_ID" --region "$REGION" \
    --query "Items[0].IntegrationId" --output text 2>/dev/null || echo "")
  [ "$INTEGRATION_ID" = "None" ] && INTEGRATION_ID=""
  ROUTE_ID=$(aws_cmd apigatewayv2 get-routes --api-id "$API_ID" --region "$REGION" \
    --query "Items[?RouteKey=='POST /apply'].RouteId | [0]" --output text 2>/dev/null || echo "")
  [ "$ROUTE_ID" = "None" ] && ROUTE_ID=""
  echo "  API Integration: ${INTEGRATION_ID:-NOT FOUND}"
  echo "  API Route: ${ROUTE_ID:-NOT FOUND}"
fi

# ACM Certificate — prefer ISSUED status, us-east-1
CERT_ARN=$(aws_cmd acm list-certificates --region "$REGION_US" --certificate-statuses ISSUED \
  --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn | [0]" --output text 2>/dev/null || echo "")
[ "$CERT_ARN" = "None" ] && CERT_ARN=""
# Fallback to any status if no ISSUED cert found
if [ -z "$CERT_ARN" ]; then
  CERT_ARN=$(aws_cmd acm list-certificates --region "$REGION_US" \
    --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn | [0]" --output text 2>/dev/null || echo "")
  [ "$CERT_ARN" = "None" ] && CERT_ARN=""
fi
echo "  ACM Certificate: ${CERT_ARN:-NOT FOUND}"

# Check for duplicate ACM certs
ALL_CERT_ARNS=$(aws_cmd acm list-certificates --region "$REGION_US" \
  --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn" --output text 2>/dev/null || echo "")
CERT_COUNT=$(echo "$ALL_CERT_ARNS" | wc -w | tr -d ' ')
if [ "$CERT_COUNT" -gt 1 ]; then
  echo ""
  echo "  WARNING: Found $CERT_COUNT ACM certificates for $DOMAIN."
  echo "  After import, delete unused certificates from the AWS console (us-east-1)."
fi

# Cert validation record names
CERT_VALIDATION_APEX=""
CERT_VALIDATION_WWW=""
if [ -n "$CERT_ARN" ]; then
  CERT_VALIDATION_APEX=$(aws_cmd acm describe-certificate --certificate-arn "$CERT_ARN" --region "$REGION_US" \
    --query "Certificate.DomainValidationOptions[?DomainName=='$DOMAIN'].ResourceRecord.Name | [0]" --output text 2>/dev/null || echo "")
  [ "$CERT_VALIDATION_APEX" = "None" ] && CERT_VALIDATION_APEX=""
  CERT_VALIDATION_WWW=$(aws_cmd acm describe-certificate --certificate-arn "$CERT_ARN" --region "$REGION_US" \
    --query "Certificate.DomainValidationOptions[?DomainName=='www.$DOMAIN'].ResourceRecord.Name | [0]" --output text 2>/dev/null || echo "")
  [ "$CERT_VALIDATION_WWW" = "None" ] && CERT_VALIDATION_WWW=""
  echo "  Cert validation (apex): ${CERT_VALIDATION_APEX:-NOT FOUND}"
  echo "  Cert validation (www): ${CERT_VALIDATION_WWW:-NOT FOUND}"
fi

echo "  Route53 Zone: $ZONE_ID"

# ─── Step 4: Import resources ───
echo ""
echo "[4/5] Importing resources into Terraform state..."
echo ""

import_resource() {
  local addr="$1"
  local id="$2"
  local label="$3"

  if [ -z "$id" ]; then
    echo "  SKIP  $label — not found in AWS"
    ((SKIPPED++)) || true
    return
  fi

  echo -n "  IMPORT $label ... "
  local output
  if output=$(terraform import "$addr" "$id" 2>&1); then
    echo "OK"
    ((IMPORTED++)) || true
  else
    if echo "$output" | grep -q "Resource already managed"; then
      echo "ALREADY IN STATE"
      ((SKIPPED++)) || true
    else
      echo "FAILED"
      echo "         $output" | head -3
      ((ERRORS++)) || true
    fi
  fi
}

# S3
import_resource "aws_s3_bucket.website" "$BUCKET" "S3 bucket"
import_resource "aws_s3_bucket_server_side_encryption_configuration.website" "$BUCKET" "S3 encryption"
import_resource "aws_s3_bucket_public_access_block.website" "$BUCKET" "S3 public access block"
import_resource "aws_s3_bucket_policy.website" "$BUCKET" "S3 bucket policy"

# DynamoDB
import_resource "aws_dynamodb_table.applications" "$TABLE" "DynamoDB table"

# CloudFront
import_resource "aws_cloudfront_origin_access_control.website" "$OAC_ID" "CloudFront OAC"
import_resource "aws_cloudfront_distribution.website" "$DIST_ID" "CloudFront distribution"

# Lambda
import_resource "aws_lambda_function.apply" "$LAMBDA" "Lambda function"
import_resource "aws_lambda_permission.apigw" "$LAMBDA_PERM" "Lambda permission"

# API Gateway
import_resource "aws_apigatewayv2_api.api" "$API_ID" "API Gateway"
if [ -n "$API_ID" ]; then
  import_resource "aws_apigatewayv2_stage.prod" "${API_ID}/\$default" "API Gateway stage"
  if [ -n "$INTEGRATION_ID" ]; then
    import_resource "aws_apigatewayv2_integration.lambda" "${API_ID}/${INTEGRATION_ID}" "API Gateway integration"
  fi
  if [ -n "$ROUTE_ID" ]; then
    import_resource "aws_apigatewayv2_route.apply" "${API_ID}/${ROUTE_ID}" "API Gateway route"
  fi
fi

# ACM
import_resource "aws_acm_certificate.website" "$CERT_ARN" "ACM certificate"
import_resource "aws_acm_certificate_validation.website" "$CERT_ARN" "ACM cert validation"

# Route53 cert validation records
if [ -n "$CERT_VALIDATION_APEX" ]; then
  import_resource "aws_route53_record.cert_validation[\"$DOMAIN\"]" \
    "${ZONE_ID}_${CERT_VALIDATION_APEX}_CNAME" \
    "Route53 cert validation (apex)"
fi
if [ -n "$CERT_VALIDATION_WWW" ]; then
  import_resource "aws_route53_record.cert_validation[\"www.$DOMAIN\"]" \
    "${ZONE_ID}_${CERT_VALIDATION_WWW}_CNAME" \
    "Route53 cert validation (www)"
fi

# Route53 A records
import_resource "aws_route53_record.apex" "${ZONE_ID}_${DOMAIN}_A" "Route53 apex A record"
import_resource "aws_route53_record.www" "${ZONE_ID}_www.${DOMAIN}_A" "Route53 www A record"

# ─── Step 5: Verify ───
echo ""
echo "[5/5] Running terraform plan to verify..."
echo ""
terraform plan -out=import-verify.tfplan -input=false 2>&1 | tail -20
rm -f import-verify.tfplan

echo ""
echo "=== Summary ==="
echo "  Imported: $IMPORTED"
echo "  Skipped:  $SKIPPED"
echo "  Errors:   $ERRORS"
echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo "Some imports failed. Review the errors above, fix manually, then re-run."
  exit 1
else
  echo "Import complete. Review the plan output above."
  echo "If it shows only expected changes (Lambda code update), commit and push."
fi
