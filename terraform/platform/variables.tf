variable "platform_name" {
  type        = string
  description = "Base name threaded through every resource and the SSM prefix (/<platform_name>/<env>/...); change once to re-skin"
  default     = "platform"
}
variable "env" { type = string }
variable "region" { type = string }
variable "interface_version" {
  type        = string
  default     = "1"
  description = "Published at <prefix>/interface/version. API stacks pin the version they were written against; bump on any breaking change to the interface (docs/interface)."
}

# --- Network -------------------------------------------------------------------
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "enable_egress_static_ip" {
  type        = bool
  default     = false
  description = "NAT + EIP so every API on the platform egresses from one stable IP (opt-in, costs)"
}
variable "enable_ingress_static_ip" {
  type    = bool
  default = false
  # Interdependent flags are guarded here (1.9+ cross-variable validation) so
  # the failure names the flag instead of a null interpolation deep in a module.
  validation {
    condition     = !var.enable_ingress_static_ip || length(var.ingress_target_ips) > 0
    error_message = "enable_ingress_static_ip requires ingress_target_ips (the execute-api endpoint ENI IPs)."
  }
}
variable "ingress_target_ips" {
  type        = list(string)
  default     = []
  description = "Private IPs of the execute-api VPC endpoint ENIs (required when enable_ingress_static_ip is true)"
}

# --- Edge -----------------------------------------------------------------------
variable "enable_waf" {
  type    = bool
  default = false
  validation {
    condition     = var.env != "prod" || var.enable_waf
    error_message = "enable_waf must be true in prod (every API's stage attaches to the platform ACL)."
  }
}
variable "waf_rate_limit" {
  type    = number
  default = 2000
}
variable "dns_enabled" {
  type    = bool
  default = false
  validation {
    condition     = !var.dns_enabled || (var.base_domain != null && var.hosted_zone_id != null)
    error_message = "dns_enabled requires base_domain and hosted_zone_id."
  }
}
variable "base_domain" {
  type        = string
  default     = null
  description = "The environment's base domain (APIs get <service>.<base_domain>); needs dns_enabled"
}
variable "hosted_zone_id" {
  type    = string
  default = null
}
variable "manage_apigw_account_settings" {
  type        = bool
  default     = true
  description = "Manage the account-wide API Gateway CloudWatch role from this env (exactly one env per account+region)."
}

# --- Identity -------------------------------------------------------------------
variable "callback_urls" {
  type        = list(string)
  default     = ["http://localhost:3000/callback"]
  description = "Hosted-UI OAuth redirect URIs for the app client. Must be https, non-localhost in prod."
  validation {
    condition     = var.env != "prod" || !anytrue([for u in var.callback_urls : !startswith(u, "https://")])
    error_message = "callback_urls must all be https:// (no localhost) in prod."
  }
}
variable "logout_urls" {
  type    = list(string)
  default = ["http://localhost:3000/"]
  validation {
    condition     = var.env != "prod" || !anytrue([for u in var.logout_urls : !startswith(u, "https://")])
    error_message = "logout_urls must all be https:// (no localhost) in prod."
  }
}
variable "enable_test_client" {
  type    = bool
  default = false
  validation {
    condition     = var.env != "prod" || !var.enable_test_client
    error_message = "The USER_PASSWORD_AUTH test client must not be enabled in prod."
  }
}
variable "mfa_configuration" {
  type    = string
  default = "OPTIONAL"
}
variable "advanced_security_mode" {
  type    = string
  default = "OFF"
}
variable "pretoken_dist_dir" {
  type    = string
  default = "../../../packages/cognito-pretoken/dist"
}

# --- Hardening / ops ------------------------------------------------------------
variable "deletion_protection" {
  type    = bool
  default = false
  validation {
    condition     = var.env != "prod" || var.deletion_protection
    error_message = "deletion_protection must be true in prod."
  }
}
variable "alarm_email" {
  type    = string
  default = null
  validation {
    condition     = var.env != "prod" || var.alarm_email != null
    error_message = "alarm_email is required in prod, otherwise every API's alarms fire into a topic with no subscriber."
  }
}
variable "monthly_budget_usd" {
  type        = number
  default     = null
  description = "If set (with alarm_email), creates a monthly cost budget alarm for the environment"
}
variable "log_retention_days" {
  type        = number
  default     = 365
  description = "CloudWatch retention for the platform's log groups (flow logs, pre-token trigger, WAF). Prod-grade default; dev tfvars shorten it."
}

variable "tags" {
  type    = map(string)
  default = {}
}
