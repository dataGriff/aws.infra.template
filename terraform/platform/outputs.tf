# Mirrors of the published interface, for humans and CI. API stacks read the
# SSM parameters, never these outputs.
output "ssm_prefix" { value = local.ssm_prefix }
output "interface_parameters" {
  value       = module.interface.names
  description = "Every published parameter name, keyed by interface path"
}
output "vpc_id" { value = module.network.vpc_id }
output "private_subnet_ids" { value = module.network.private_subnet_ids }
output "cognito_user_pool_id" { value = module.cognito.user_pool_id }
output "cognito_app_client_id" { value = module.cognito.app_client_id }
output "cognito_test_client_id" { value = module.cognito.test_client_id }
output "cognito_issuer" { value = module.cognito.issuer }
output "alarm_topic_arn" { value = module.alarms.topic_arn }
output "egress_static_ip" { value = module.network.egress_ip }
output "ingress_static_ips" {
  value = var.enable_ingress_static_ip ? module.ingress_static_ip[0].static_ips : null
}
output "certificate_arn" {
  value = var.dns_enabled ? module.dns[0].certificate_arn : null
}
