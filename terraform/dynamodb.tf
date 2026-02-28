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
    Project   = "digi-dan-oss"
    Component = "join-website"
    ManagedBy = "terraform"
  }
}
