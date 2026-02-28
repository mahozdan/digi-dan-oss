# ─── API Gateway: HTTP API ───

resource "aws_apigatewayv2_api" "api" {
  name          = "digi-dan-oss-join-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["Content-Type"]
    max_age       = 3600
  }

  tags = {
    Project   = "digi-dan-oss"
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
