variable "name" { type = string }
variable "kms_key_arn" {
  type        = string
  description = "CMK for the topic (policy must allow cloudwatch.amazonaws.com)"
}
variable "alarm_email" {
  type        = string
  default     = null
  description = "Email to subscribe to the alarm topic (must confirm once)"
}
variable "tags" {
  type    = map(string)
  default = {}
}
