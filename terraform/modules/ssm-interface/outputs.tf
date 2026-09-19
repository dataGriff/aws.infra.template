output "names" {
  value       = { for k, p in aws_ssm_parameter.this : k => p.name }
  description = "Published parameter names keyed by interface path"
}
