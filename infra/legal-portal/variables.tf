variable "region" {
  description = "AWS region for the S3 bucket (CloudFront is global; keep us-east-1 for ACM compatibility)."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Override the S3 bucket name. Empty = pawdoc-legal-<account-id>."
  type        = string
  default     = ""
}

variable "dist_path" {
  description = "Path to the built static site (output of web-legal/build.mjs)."
  type        = string
  default     = "../../web-legal/dist"
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_100 = NA+EU, cheapest)."
  type        = string
  default     = "PriceClass_100"
}

variable "aliases" {
  description = "Optional custom domains for the distribution (e.g. [\"legal.pawdoc.app\"]). Requires acm_certificate_arn. Empty = use CloudFront default domain."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for the custom domain(s). Empty = use the CloudFront default certificate."
  type        = string
  default     = ""
}
