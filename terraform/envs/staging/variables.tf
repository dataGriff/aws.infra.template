variable "region" {
  type    = string
  default = "eu-west-2"
}
variable "platform_name" {
  type    = string
  default = "platform"
}
variable "allowed_account_ids" {
  type        = list(string)
  default     = []
  description = "Safety guard: if non-empty, Terraform refuses to run against any AWS account not in this list, so a wrong active profile can't deploy to the wrong account. Set it to this env's account id in terraform.tfvars."
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "enable_egress_static_ip" {
  type    = bool
  default = false
}
# PrivateLink bills per interface endpoint PER AZ; the platform validates that prod
# keeps the full set across >= 2 AZs (terraform/platform/variables.tf).
variable "interface_endpoints" {
  type    = list(string)
  default = ["secretsmanager", "logs", "sts", "kms", "xray"]
}
variable "endpoint_az_count" {
  type    = number
  default = null
}
variable "enable_ingress_static_ip" {
  type    = bool
  default = false
}
variable "ingress_target_ips" {
  type    = list(string)
  default = []
}
variable "enable_waf" {
  type    = bool
  default = false
}
variable "dns_enabled" {
  type    = bool
  default = false
}
variable "base_domain" {
  type    = string
  default = null
}
variable "hosted_zone_id" {
  type    = string
  default = null
}
variable "manage_apigw_account_settings" {
  type        = bool
  default     = true
  description = "Exactly ONE env per AWS account+region may manage the API Gateway account role; set false in the others."
}
variable "callback_urls" {
  type    = list(string)
  default = ["http://localhost:3000/callback"]
}
variable "logout_urls" {
  type    = list(string)
  default = ["http://localhost:3000/"]
}
variable "mfa_configuration" {
  type    = string
  default = "OPTIONAL"
}
variable "advanced_security_mode" {
  type    = string
  default = "OFF"
}
variable "alarm_email" {
  type    = string
  default = null
}
variable "monthly_budget_usd" {
  type    = number
  default = null
}
variable "log_retention_days" {
  type    = number
  default = 365
}
