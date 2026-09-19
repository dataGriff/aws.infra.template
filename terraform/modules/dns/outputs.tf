output "certificate_arn" {
  value       = aws_acm_certificate_validation.wildcard.certificate_arn
  description = "Validated regional wildcard certificate for *.<base_domain>"
}
output "base_domain" { value = var.base_domain }
output "hosted_zone_id" { value = var.hosted_zone_id }
