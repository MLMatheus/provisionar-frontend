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

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
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
    
    cache_policy_id          = aws_cloudfront_cache_policy.optimized_cache.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.optimized_request.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["BR"]
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.certificate.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  aliases = [var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name]
}

resource "aws_cloudfront_cache_policy" "optimized_cache" {
  name        = "optimized-cache-policy"
  comment     = "Política de cache otimizada para S3"
  default_ttl = 86400   # Cache de 24 horas
  max_ttl     = 604800  # Cache máximo de 7 dias
  min_ttl     = 3600    # Cache mínimo de 1 hora

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    cookies_config {
      cookie_behavior = "none"  # Nenhum cookie será armazenado no cache
    }

    headers_config {
      header_behavior = "none"  # Nenhum cabeçalho será enviado à origem
    }

    query_strings_config {
      query_string_behavior = "none"  # Nenhuma query string será armazenada no cache
    }
  }
}

resource "aws_cloudfront_origin_request_policy" "optimized_request" {
  name    = "optimized-request-policy"
  comment = "Política de requisição otimizada para S3"

  cookies_config {
    cookie_behavior = "none"
  }

  headers_config {
    header_behavior = "none"
  }

  query_strings_config {
    query_string_behavior = "none"
  }
}

resource "aws_acm_certificate" "certificate" {
  domain_name       = var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name
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
  name    = var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.frontend_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

data "aws_route53_zone" "main" {
  name = var.domain_name
}
