# ─── Outputs ───

output "cloudfront_url" {
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
  description = "CloudFront URL — this is your public site URL (Israel only)"
}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.website.id
  description = "CloudFront distribution ID — needed for cache invalidation"
}

output "api_url" {
  value       = aws_apigatewayv2_api.api.api_endpoint
  description = "API Gateway URL — replace {{API_GATEWAY_URL}} in index.html"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.website.id
  description = "S3 bucket for site files"
}

output "dynamodb_table" {
  value       = aws_dynamodb_table.applications.name
  description = "DynamoDB table storing applications"
}
