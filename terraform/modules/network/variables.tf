variable "name" { type = string }
variable "region" { type = string }
variable "cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "azs" { type = list(string) }
variable "enable_egress_static_ip" {
  type    = bool
  default = false
}
variable "interface_endpoints" {
  type        = list(string)
  description = "Interface endpoints the private subnets need (no NAT by default): every AWS API the Lambda calls, including X-Ray for tracing. Empty means none — nothing in the private subnets can reach an AWS API without NAT."
  default     = ["secretsmanager", "logs", "sts", "kms", "xray"]
}
variable "endpoint_az_count" {
  type        = number
  default     = null
  description = "How many AZs each interface endpoint gets an ENI in (null = every private subnet). PrivateLink bills per endpoint PER AZ, so this is the cost dial; below the AZ count there is no endpoint redundancy."
  validation {
    condition     = coalesce(var.endpoint_az_count, 1) >= 1
    error_message = "endpoint_az_count must be at least 1 (use interface_endpoints = [] to create none)."
  }
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "kms_key_arn" {
  type        = string
  default     = null
  description = "CMK for the flow-log log group"
}
variable "log_retention_days" {
  type    = number
  default = 365
}
