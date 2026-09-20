variable "prefix" {
  type        = string
  description = "Parameter name prefix, e.g. /platform/dev (no trailing slash)"
  validation {
    condition     = startswith(var.prefix, "/") && !endswith(var.prefix, "/")
    error_message = "prefix must start with / and not end with /."
  }
}
variable "parameters" {
  description = "Parameters to publish, keyed by their path below the prefix (e.g. network/vpc_id)"
  type = map(object({
    value       = string
    type        = optional(string, "String")
    description = optional(string, "")
  }))
  validation {
    condition     = alltrue([for p in values(var.parameters) : contains(["String", "StringList"], p.type)])
    error_message = "Only String and StringList are published through the interface (no secrets)."
  }
}
variable "tags" {
  type    = map(string)
  default = {}
}
