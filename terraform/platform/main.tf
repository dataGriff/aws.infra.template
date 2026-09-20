terraform {
  # 1.9+: variable validation rules may reference other variables (used for the
  # prod guardrails in variables.tf).
  required_version = ">= 1.9"
  required_providers {
    aws     = { source = "hashicorp/aws", version = ">= 5.60" }
    random  = { source = "hashicorp/random", version = ">= 3.6" }
    archive = { source = "hashicorp/archive", version = ">= 2.4" }
  }
}

# The platform for ONE environment: everything shared by every API deployed
# into it. API stacks (aws.api.template) consume it only through the SSM
# parameters published at the end of this file (see docs/interface).

data "aws_availability_zones" "available" {
  state = "available"
}

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  special = false
}

locals {
  name       = "${var.platform_name}-${var.env}"
  azs        = slice(data.aws_availability_zones.available.names, 0, 2)
  ssm_prefix = "/${var.platform_name}/${var.env}"
  tags = merge(var.tags, {
    Platform    = var.platform_name
    Environment = var.env
    ManagedBy   = "terraform"
  })
}

module "kms" {
  source                  = "../modules/kms"
  name                    = local.name
  region                  = var.region
  deletion_window_in_days = var.deletion_protection ? 30 : 7
  tags                    = local.tags
}

module "network" {
  source                  = "../modules/network"
  name                    = local.name
  region                  = var.region
  azs                     = local.azs
  cidr                    = var.vpc_cidr
  enable_egress_static_ip = var.enable_egress_static_ip
  kms_key_arn             = module.kms.ops_key_arn
  log_retention_days      = var.log_retention_days
  tags                    = local.tags
}

module "cognito" {
  source                 = "../modules/cognito"
  name                   = local.name
  region                 = var.region
  domain_suffix          = random_string.suffix.result
  pretoken_dist_dir      = var.pretoken_dist_dir
  enable_test_client     = var.enable_test_client
  callback_urls          = var.callback_urls
  logout_urls            = var.logout_urls
  deletion_protection    = var.deletion_protection
  mfa_configuration      = var.mfa_configuration
  advanced_security_mode = var.advanced_security_mode
  log_retention_days     = var.log_retention_days
  kms_key_arn            = module.kms.ops_key_arn
  tags                   = local.tags
}

module "waf" {
  count              = var.enable_waf ? 1 : 0
  source             = "../modules/waf"
  name               = local.name
  rate_limit         = var.waf_rate_limit
  kms_key_arn        = module.kms.ops_key_arn
  log_retention_days = var.log_retention_days
  tags               = local.tags
}

module "dns" {
  count          = var.dns_enabled ? 1 : 0
  source         = "../modules/dns"
  base_domain    = var.base_domain
  hosted_zone_id = var.hosted_zone_id
  tags           = local.tags
}

module "ingress_static_ip" {
  count               = var.enable_ingress_static_ip ? 1 : 0
  source              = "../modules/ingress-static-ip"
  name                = local.name
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.private_subnet_ids
  target_ips          = var.ingress_target_ips
  deletion_protection = var.deletion_protection
  tags                = local.tags
}

module "alarms" {
  source      = "../modules/alarms"
  name        = local.name
  kms_key_arn = module.kms.ops_key_arn
  alarm_email = var.alarm_email
  tags        = local.tags
}

module "apigw_account" {
  source                  = "../modules/apigw-account"
  name                    = local.name
  manage_account_settings = var.manage_apigw_account_settings
  tags                    = local.tags
}

module "budget" {
  source             = "../modules/budget"
  name               = local.name
  monthly_budget_usd = var.monthly_budget_usd
  alarm_email        = var.alarm_email
}

# --- The published interface ---------------------------------------------------
# Keys are known at plan time (only values are unknown), which is what the
# for_each in the module needs. Optional entries exist only when their feature
# is on, so an API reading them fails loudly instead of getting a placeholder.
locals {
  interface_always = {
    "interface/version"               = { value = var.interface_version, description = "Interface version; bumped on any breaking change to names or semantics" }
    "network/vpc_id"                  = { value = module.network.vpc_id }
    "network/vpc_cidr"                = { value = module.network.vpc_cidr }
    "network/private_subnet_ids"      = { value = join(",", module.network.private_subnet_ids), type = "StringList" }
    "network/public_subnet_ids"       = { value = join(",", module.network.public_subnet_ids), type = "StringList" }
    "network/dynamodb_prefix_list_id" = { value = module.network.dynamodb_prefix_list_id }
    "network/nat_enabled"             = { value = tostring(module.network.nat_enabled) }
    "kms/data_key_arn"                = { value = module.kms.data_key_arn }
    "kms/ops_key_arn"                 = { value = module.kms.ops_key_arn }
    "cognito/user_pool_id"            = { value = module.cognito.user_pool_id }
    "cognito/user_pool_arn"           = { value = module.cognito.user_pool_arn }
    "cognito/issuer"                  = { value = module.cognito.issuer }
    "cognito/app_client_id"           = { value = module.cognito.app_client_id }
    "cognito/hosted_ui_domain"        = { value = module.cognito.hosted_ui_domain }
    "alarms/topic_arn"                = { value = module.alarms.topic_arn }
    "apigw/cloudwatch_role_arn"       = { value = module.apigw_account.cloudwatch_role_arn }
  }
  interface_optional = merge(
    var.enable_egress_static_ip ? { "network/egress_ip" = { value = module.network.egress_ip } } : {},
    var.enable_test_client ? { "cognito/test_client_id" = { value = module.cognito.test_client_id } } : {},
    var.enable_waf ? { "waf/web_acl_arn" = { value = module.waf[0].web_acl_arn } } : {},
    var.dns_enabled ? {
      "dns/hosted_zone_id"  = { value = module.dns[0].hosted_zone_id }
      "dns/base_domain"     = { value = module.dns[0].base_domain }
      "dns/certificate_arn" = { value = module.dns[0].certificate_arn }
    } : {},
    var.enable_ingress_static_ip ? { "ingress/static_ips" = { value = join(",", module.ingress_static_ip[0].static_ips), type = "StringList" } } : {},
  )
}

module "interface" {
  source     = "../modules/ssm-interface"
  prefix     = local.ssm_prefix
  parameters = merge(local.interface_always, local.interface_optional)
  tags       = local.tags
}
