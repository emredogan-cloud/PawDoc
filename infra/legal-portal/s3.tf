# Private origin bucket — no public access; CloudFront-only via OAC.

resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    object_ownership = "BucketOwnerEnforced" # disables ACLs; correct with OAC
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Upload the built site. Re-uploads on content change (etag = md5).
resource "aws_s3_object" "site" {
  for_each = local.files

  bucket        = aws_s3_bucket.site.id
  key           = each.value
  source        = "${var.dist_path}/${each.value}"
  etag          = filemd5("${var.dist_path}/${each.value}")
  content_type  = lookup(local.content_types, element(reverse(split(".", each.value)), 0), "application/octet-stream")
  cache_control = endswith(each.value, ".html") ? "public, max-age=300, must-revalidate" : "public, max-age=3600"

  tags = local.common_tags
}
