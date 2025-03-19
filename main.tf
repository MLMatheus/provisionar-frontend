resource "aws_s3_bucket" "meu_bucket" {
  bucket        = var.s3_front
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "meu_bucket_website" {
  bucket = aws_s3_bucket.meu_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_public_access_block" "meu_bucket_public_access_block" {
  bucket = aws_s3_bucket.meu_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_access_policy" {
  bucket = aws_s3_bucket.meu_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.meu_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.s3_front}-oac"
  description                       = "OAC for ${var.s3_front} S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend_distribution" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.meu_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.meu_bucket.id}"

    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = "S3-${aws_s3_bucket.meu_bucket.id}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.certificate.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  aliases = [var.subdomain + var.subdomain == "" ? "" : "." + var.domain_name]
}

# Certificado SSL (ACM) para o domínio personalizado
resource "aws_acm_certificate" "certificate" {
  domain_name       = var.subdomain + var.subdomain == "" ? "" : "." + var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "frontend_dns_validation" {
  for_each = {
    for dvo in aws_acm_certificate.certificate.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]
}

resource "aws_route53_record" "frontend_alias" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.subdomain + var.subdomain == "" ? "" : "." + var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend_distribution
    zone_id                = aws_cloudfront_distribution.frontend_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

data "aws_route53_zone" "main" {
  name = var.domain_name
}
