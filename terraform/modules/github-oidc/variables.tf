variable "create_provider" {
  type        = bool
  default     = true
  description = "Create the account's GitHub OIDC provider (set false if another stack already owns it; it is then looked up)."
}
variable "roles" {
  description = "Deploy roles to create, keyed by role name. admin = AdministratorAccess (platform); otherwise PowerUserAccess + IAM scoped to iam_name_prefix + read of the platform interface under ssm_prefix."
  type = map(object({
    github_repository = string
    environment       = string
    admin             = bool
    state_bucket_arn  = string
    lock_table_arn    = string
    state_kms_key_arn = string
    iam_name_prefix   = optional(string, "")
    ssm_prefix        = optional(string, "/platform")
  }))
}
variable "tags" {
  type    = map(string)
  default = {}
}
