variable "name" { type = string }
variable "monthly_budget_usd" {
  type    = number
  default = null
}
variable "alarm_email" {
  type    = string
  default = null
}
