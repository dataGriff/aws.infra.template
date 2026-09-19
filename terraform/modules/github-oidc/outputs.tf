output "provider_arn" { value = local.provider_arn }
output "role_arns" { value = { for k, r in aws_iam_role.deploy : k => r.arn } }
