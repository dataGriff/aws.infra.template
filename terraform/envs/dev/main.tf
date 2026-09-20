module "platform" {
  source = "../../platform"

  platform_name = var.platform_name
  env           = "dev"
  region        = var.region

  vpc_cidr                 = var.vpc_cidr
  enable_egress_static_ip  = var.enable_egress_static_ip
  interface_endpoints      = var.interface_endpoints
  endpoint_az_count        = var.endpoint_az_count
  enable_ingress_static_ip = var.enable_ingress_static_ip
  ingress_target_ips       = var.ingress_target_ips
  enable_waf               = var.enable_waf
  dns_enabled              = var.dns_enabled
  base_domain              = var.base_domain
  hosted_zone_id           = var.hosted_zone_id

  manage_apigw_account_settings = var.manage_apigw_account_settings
  callback_urls                 = var.callback_urls
  logout_urls                   = var.logout_urls
  mfa_configuration             = var.mfa_configuration
  advanced_security_mode        = var.advanced_security_mode
  alarm_email                   = var.alarm_email
  monthly_budget_usd            = var.monthly_budget_usd
  log_retention_days            = var.log_retention_days

  # dev: password-auth test client for CI / Schemathesis; ephemeral
  enable_test_client  = true
  deletion_protection = false
}
