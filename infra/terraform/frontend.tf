# The SPA's bucket, private behind an Origin Access Control, and the one
# CloudFront distribution that fronts both it and the ALB. This is the
# "single origin, no CORS" shape the README describes: S3 is the default
# behavior, /api/* goes to the ALB with caching off, and both 403 (private
# bucket's response to a path that doesn't exist) and 404 rewrite to
# /index.html so client-side routes survive a hard refresh.

resource "aws_s3_bucket" "frontend" {
  bucket = local.frontend_bucket_name

  tags = {
    Name = local.frontend_bucket_name
  }
}

resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --------------------------------------------------------- CloudFront logs --
# Standard CloudFront logging still requires the legacy "log-delivery-write"
# canned ACL on the target bucket, so - unlike the frontend bucket - object
# ownership here has to stay ACL-friendly. It is otherwise locked down the
# same way (no public access, SSE, nothing but CloudFront's log delivery
# writing to it).

resource "aws_s3_bucket" "cf_logs" {
  bucket = local.cf_logs_bucket_name

  tags = {
    Name = local.cf_logs_bucket_name
  }
}

resource "aws_s3_bucket_ownership_controls" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id
  acl    = "log-delivery-write"

  depends_on = [aws_s3_bucket_ownership_controls.cf_logs]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }
  }
}

# ------------------------------------------------------------------- OAC ----

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = local.frontend_bucket_name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_iam_policy_document" "frontend_bucket" {
  statement {
    sid     = "AllowCloudFrontServicePrincipal"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.main.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_bucket.json
}

# -------------------------------------------------------------- cache/origin --
# AWS managed policies, not bespoke ones: "CachingOptimized" for the SPA's
# hashed, immutable assets and the no-store shell alike (Cache-Control from
# nginx/the S3 object wins either way), "CachingDisabled" plus "AllViewer"
# for the API so every header, cookie and query string reaches the ALB
# unchanged.

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}

# ----------------------------------------------------------- distribution --

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = local.name

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "frontend-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "backend-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    # The only thing that lets a request through the ALB's listener rule
    # (see security.tf) - CloudFront attaches it to every origin request,
    # and nothing else knows the value.
    custom_header {
      name  = local.cloudfront_origin_header_name
      value = local.cloudfront_origin_header_value
    }
  }

  default_cache_behavior {
    target_origin_id       = "frontend-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  ordered_cache_behavior {
    path_pattern             = "/api/*"
    target_origin_id         = "backend-alb"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
  }

  # Both come from a private bucket denying everything but CloudFront:
  # 403 is "object not found" to a bucket that has no public ListBucket, and
  # 404 is a genuinely missing key. Either way, hand the client-side router
  # index.html and let it decide.
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # CloudFront's shared default certificate only ever negotiates TLSv1 and
  # rejects a custom minimum_protocol_version alongside it; a higher floor
  # needs a dedicated ACM certificate, which needs a domain this demo
  # doesn't have.
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  logging_config {
    bucket          = aws_s3_bucket.cf_logs.bucket_domain_name
    prefix          = "cloudfront/"
    include_cookies = false
  }

  tags = {
    Name = local.name
  }
}
