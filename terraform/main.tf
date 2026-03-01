terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  backend "s3" {
    bucket = "digi-dan-oss-tfstate"
    key    = "join-site/terraform.tfstate"
    region = "il-central-1"
  }
}

provider "aws" {
  region = "il-central-1" # NEVER make this a variable
}

# ACM certificates for CloudFront must be in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

variable "domain_name" {
  description = "Primary domain for the site (apex)"
  type        = string
  default     = "digi-dan.com"
}

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
