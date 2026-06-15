output "bucket_name" {
  description = "S3 bucket holding the static site."
  value       = aws_s3_bucket.site.id
}

output "distribution_id" {
  description = "CloudFront distribution ID (for invalidations)."
  value       = aws_cloudfront_distribution.site.id
}

output "cloudfront_domain" {
  description = "CloudFront default domain."
  value       = aws_cloudfront_distribution.site.domain_name
}

output "portal_url" {
  description = "Public HTTPS URL of the legal portal."
  value       = var.acm_certificate_arn == "" ? "https://${aws_cloudfront_distribution.site.domain_name}" : "https://${var.aliases[0]}"
}
