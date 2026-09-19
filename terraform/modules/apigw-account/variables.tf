variable "name" { type = string }
variable "manage_account_settings" {
  type        = bool
  default     = true
  description = "Set the account-level API Gateway CloudWatch role (exactly one platform env per account+region). false only when several envs share an account/region and another env manages it."
}
variable "tags" {
  type    = map(string)
  default = {}
}
