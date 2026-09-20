variable "name" { type = string }
variable "region" { type = string }
variable "deletion_window_in_days" {
  type        = number
  default     = 30
  description = "Shared keys encrypt every API's data; keep the window long (dev tfvars may shorten it)."
}
variable "tags" {
  type    = map(string)
  default = {}
}
