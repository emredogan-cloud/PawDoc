# PawDoc Legal Portal — AWS static hosting (S3 + CloudFront).
# Private S3 bucket reached only through CloudFront via Origin Access Control.
# Public HTTPS over the CloudFront default certificate; optional custom domain.
# Region us-east-1 (CloudFront + any future ACM cert must live there).

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

locals {
  bucket_name = var.bucket_name != "" ? var.bucket_name : "pawdoc-legal-${data.aws_caller_identity.current.account_id}"

  # All built files, with per-extension content types + cache policy.
  files = fileset(var.dist_path, "**")

  content_types = {
    html = "text/html; charset=utf-8"
    css  = "text/css; charset=utf-8"
    svg  = "image/svg+xml"
    xml  = "application/xml; charset=utf-8"
    txt  = "text/plain; charset=utf-8"
    json = "application/json"
    ico  = "image/x-icon"
    png  = "image/png"
    js   = "text/javascript; charset=utf-8"
  }

  common_tags = {
    Project   = "pawdoc"
    Component = "legal-portal"
    ManagedBy = "terraform"
  }
}
