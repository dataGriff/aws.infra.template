# Names are derived and recomputed by the deploy tasks — the state outputs are
# for reference/verification, not something you copy into GitHub secrets.
output "state_buckets" { value = { for k, m in module.backend : k => m.state_bucket } }
output "lock_tables" { value = { for k, m in module.backend : k => m.lock_table } }
output "state_kms_aliases" { value = { for k, m in module.backend : k => m.kms_alias } }

output "platform_deploy_role_arns" {
  description = "Set each env's value as AWS_DEPLOY_ROLE_ARN on the matching GitHub Environment of THIS repo"
  value = {
    for env in var.deploy_environments :
    env => module.github_oidc.role_arns["${var.deploy_role_prefix}-${var.platform_name}-${env}"]
  }
}
output "service_deploy_role_arns" {
  description = "Per service, per env: the AWS_DEPLOY_ROLE_ARN to set on that env's GitHub Environment in the SERVICE's repo"
  value = {
    for s in var.services : s.name => {
      for env in var.deploy_environments :
      env => module.github_oidc.role_arns["${var.deploy_role_prefix}-${s.name}-${env}"]
    }
  }
}
