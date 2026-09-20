output "provider_arn" { value = local.provider_arn }
output "role_arns" { value = { for k, r in aws_iam_role.deploy : k => r.arn } }
# Known at plan time (derived from the input, not from created resources), so
# tests can assert on the role set without applying.
output "admin_role_names" { value = sort([for k, r in var.roles : k if r.admin]) }
output "service_role_names" { value = sort([for k, r in var.roles : k if !r.admin]) }
output "interface_protected_role_names" {
  value       = sort(keys(aws_iam_role_policy.protect_platform_interface))
  description = "Roles carrying the explicit deny on the platform SSM namespace (every non-admin role)"
}
output "workload_boundary_arns" {
  value       = { for k, p in aws_iam_policy.workload_boundary : k => p.arn }
  description = "Per service role: the permissions boundary its created roles must carry"
}
output "workload_boundary_names" {
  value       = sort([for k, r in var.roles : "${r.iam_name_prefix}workload-boundary" if !r.admin])
  description = "Plan-time known boundary policy names (for tests)"
}
