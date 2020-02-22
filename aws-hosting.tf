provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

locals {
  domain = "ramblings.henryjenkins.name"
}


resource "aws_acm_certificate" "ramblings" {
  domain_name       = local.domain
  validation_method = "DNS"

  tags = {
    Name = "Ramblings Blog"
  }
}

resource "aws_route53_record" "cert_validation" {
  name    = aws_acm_certificate.ramblings.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.ramblings.domain_validation_options.0.resource_record_type
  zone_id = aws_route53_zone.ramblings.id
  records = ["${aws_acm_certificate.ramblings.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "ramblings" {
  certificate_arn         = aws_acm_certificate.ramblings.arn
  validation_record_fqdns = ["${aws_route53_record.cert_validation.fqdn}"]
}

resource "aws_s3_bucket" "ramblings" {
  bucket = local.domain

  website {
    index_document = "index.html"
    error_document = "404.html"

    routing_rules = <<EOF
[{
    "Condition": {
        "KeyPrefixEquals": "/"
    },
    "Redirect": {
        "ReplaceKeyWith": "index.html"
    }
},{
    "Condition": {
        "KeyPrefixEquals": "docs/"
    },
    "Redirect": {
        "ReplaceKeyPrefixWith": "documents/"
    }
}]
EOF
  }

  tags = {
    domain = local.domain
  }
}
resource "aws_s3_bucket_policy" "ramblings" {
  bucket = aws_s3_bucket.ramblings.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Action": [
        "s3:GetObject"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::ramblings.henryjenkins.name/*",
      "Principal": "*"
    }
  ]
}
POLICY
}

resource "aws_cloudfront_origin_access_identity" "ramblings" {
  comment = "Web origin access identity"
}

resource "aws_cloudfront_distribution" "ramblings_distribution" {

  aliases = ["${local.domain}"]

  comment             = "Ramblings Blog"
  default_root_object = "index.html"
  enabled             = true
  is_ipv6_enabled     = true

  origin {
    domain_name = aws_s3_bucket.ramblings.website_endpoint
    origin_id   = "ramblings-s3"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_keepalive_timeout = 5
      origin_protocol_policy   = "http-only"
      origin_read_timeout      = 30
      origin_ssl_protocols = [
        "TLSv1.2",
      ]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "ramblings-s3"
    compress         = "true"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.ramblings.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2018"
  }

  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
  }
  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
  }
}
resource "aws_route53_zone" "ramblings" {
  name = "${local.domain}."
}

resource "aws_route53_record" "ramblings_a" {
  zone_id = aws_route53_zone.ramblings.zone_id
  name    = local.domain
  type    = "A"

  alias {
    zone_id                = aws_cloudfront_distribution.ramblings_distribution.hosted_zone_id
    name                   = aws_cloudfront_distribution.ramblings_distribution.domain_name
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "ramblings_aaaa" {
  zone_id = aws_route53_zone.ramblings.zone_id
  name    = local.domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.ramblings_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.ramblings_distribution.hosted_zone_id
    evaluate_target_health = true
  }
}
