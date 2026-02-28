terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # Uncomment after creating the state bucket (see DEPLOY.md step 2)
  # backend "s3" {
  #   bucket = "digi-dan-oss-tfstate"
  #   key    = "join-site/terraform.tfstate"
  #   region = "il-central-1"
  # }
}

provider "aws" {
  region = "il-central-1" # NEVER make this a variable
}

# CloudFront requires us-east-1 for some resources (e.g. ACM certs)
# but the default CloudFront certificate works without a second provider

variable "admin_email" {
  description = "Email to receive application notifications"
  type        = string
  default     = "tichnundan@gmail.com"
}

variable "from_email" {
  description = "Verified SES sender email"
  type        = string
  default     = "tichnundan@gmail.com"
}

variable "site_bucket_name" {
  description = "S3 bucket name for the static site"
  type        = string
  default     = "digi-dan-oss-join-site"
}
