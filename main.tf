# terraform/main.tf
# Community application website infrastructure
# S3 static site + API Gateway + Lambda + DynamoDB

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "il-central-1" # NEVER make this a variable
}

# ─── Variables ───

variable "admin_email" {
  description = "Email to receive application notifications"
  type        = string
  default     = ""
}

variable "from_email" {
  description = "Verified SES sender email"
  type        = string
  default     = ""
}

# ─── S3: Static Website Hosting ───

resource "aws_s3_bucket" "website" {
  bucket = "community-join-site"

  tags = {
    Project   = "community-platform"
    Component = "join-website"
    ManagedBy = "terraform"
  }
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document { suffix = "index.html" }
  error_document { key = "index.html" }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.website]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ─── DynamoDB: Application Storage ───

resource "aws_dynamodb_table" "applications" {
  name         = "community-applications"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  attribute {
    name = "submitted_at"
    type = "S"
  }

  global_secondary_index {
    name            = "email-index"
    hash_key        = "email"
    range_key       = "submitted_at"
    projection_type = "ALL"
  }

  point_in_time_recovery { enabled = true }

  server_side_encryption { enabled = true }

  tags = {
    Project   = "community-platform"
    Component = "join-website"
    ManagedBy = "terraform"
  }
}

# ─── Lambda: Form Handler ───

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "community-join-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_permissions" {
  # DynamoDB write access
  statement {
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.applications.arn]
  }

  # CloudWatch Logs
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:il-central-1:*:*"]
  }

  # SES send (if configured)
  statement {
    actions   = ["ses:SendEmail"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["il-central-1"]
    }
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "community-join-lambda-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/apply"
  output_path = "${path.module}/.build/apply.zip"
}

resource "aws_lambda_function" "apply" {
  function_name    = "community-join-apply"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 10
  memory_size      = 128
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  reserved_concurrent_executions = 10 # Cost protection

  environment {
    variables = {
      TABLE_NAME  = aws_dynamodb_table.applications.name
      ADMIN_EMAIL = var.admin_email
      FROM_EMAIL  = var.from_email
    }
  }

  tags = {
    Project   = "community-platform"
    Component = "join-website"
    ManagedBy = "terraform"
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.apply.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

# ─── API Gateway: HTTP API ───

resource "aws_apigatewayv2_api" "api" {
  name          = "community-join-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["Content-Type"]
    max_age       = 3600
  }

  tags = {
    Project   = "community-platform"
    Component = "join-website"
    ManagedBy = "terraform"
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.apply.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "apply" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /apply"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 10
    throttling_rate_limit  = 5
  }
}

# ─── Outputs ───

output "website_url" {
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
  description = "S3 static website URL"
}

output "api_url" {
  value       = aws_apigatewayv2_api.api.api_endpoint
  description = "API Gateway URL — replace {{API_GATEWAY_URL}} in index.html with this"
}

output "dynamodb_table" {
  value       = aws_dynamodb_table.applications.name
  description = "DynamoDB table storing applications"
}
