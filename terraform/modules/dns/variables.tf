variable "base_domain" {
  type        = string
  description = "The environment's base domain, e.g. dev.example.com; APIs get <service>.<base_domain>"
}
variable "hosted_zone_id" {
  type        = string
  description = "Route53 hosted zone id for base_domain (created outside Terraform)"
}
variable "tags" {
  type    = map(string)
  default = {}
}
