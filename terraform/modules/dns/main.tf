terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.60" }
  }
}

# The hosted zone for base_domain (e.g. dev.example.com) is created outside
# Terraform (registrar / parent-zone delegation) and passed in. The platform
# owns ONE regional wildcard certificate for it; every API creates
# <service>.<base_domain> (custom domain + base-path mapping + alias record)
# with that certificate — see the custom-domain module in aws.api.template.
resource "aws_acm_certificate" "wildcard" {
  domain_name               = "*.${var.base_domain}"
  subject_alternative_names = [var.base_domain]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
  tags = var.tags
}

# Keys are the domain names (known at plan time); the validation records are
# looked up per key so the for_each never depends on apply-time values. The
# apex and the wildcard share one CNAME, hence allow_overwrite.
locals {
  validation = {
    for name in [var.base_domain, "*.${var.base_domain}"] :
    name => [for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo if dvo.domain_name == name][0]
  }
}

resource "aws_route53_record" "validation" {
  for_each        = local.validation
  zone_id         = var.hosted_zone_id
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  records         = [each.value.resource_record_value]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}
