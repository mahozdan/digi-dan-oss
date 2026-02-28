# ─── Lambda: Form Handler ───
# IAM role "digi-dan-oss-join-lambda" is created manually in the AWS console.
# See iam/policies/iam-lambda-permissions-policy.json for its inline policy.

variable "lambda_role_arn" {
  description = "ARN of the manually-created Lambda execution role"
  type        = string
  default     = "arn:aws:iam::420432358545:role/digi-dan-oss-join-lambda"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/apply"
  output_path = "${path.module}/.build/apply.zip"
}

resource "aws_lambda_function" "apply" {
  function_name    = "digi-dan-oss-join-apply"
  role             = var.lambda_role_arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 10
  memory_size      = 128
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  # Note: reserved_concurrent_executions removed — il-central-1 account limit
  # is 10 total, and AWS requires at least 10 unreserved. Request a limit
  # increase before adding reserved concurrency.

  environment {
    variables = {
      TABLE_NAME  = aws_dynamodb_table.applications.name
      ADMIN_EMAIL = var.admin_email
      FROM_EMAIL  = var.from_email
    }
  }

  tags = {
    Project   = "digi-dan-oss"
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
