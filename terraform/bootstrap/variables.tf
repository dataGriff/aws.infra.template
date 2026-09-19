variable "region" {
  type    = string
  default = "eu-west-2"
}
variable "platform_name" {
  type        = string
  default     = "platform"
  description = "Base name for the platform's state backends and deploy roles (must match the envs' platform_name)."
}
variable "github_repository" {
  type        = string
  default     = "dataGriff/aws.infra.template"
  description = "owner/repo of THIS (platform) repository, allowed to assume the platform deploy roles"
}
variable "services" {
  description = "API services hosted on the platform. Each gets a state backend + deploy role per environment, scoped to its own state and IAM name prefix. name must equal the service_name the API repo deploys with."
  type = list(object({
    name              = string
    github_repository = string
  }))
  default = [
    { name = "todo-api", github_repository = "dataGriff/aws.api.template" },
  ]
  validation {
    condition     = length(distinct([for s in var.services : s.name])) == length(var.services)
    error_message = "service names must be unique."
  }
  validation {
    condition     = alltrue([for s in var.services : can(regex("^[a-z][a-z0-9-]{1,30}$", s.name))])
    error_message = "service names must be lower-case kebab-case (they become bucket, table and role names)."
  }
}
variable "create_github_oidc" {
  type        = bool
  default     = true
  description = "Create the GitHub OIDC provider (set false if the account already has the provider; it is then looked up)."
}
variable "deploy_environments" {
  type    = list(string)
  default = ["dev", "staging", "prod"]
}
variable "deploy_role_prefix" {
  type    = string
  default = "github-deploy"
}
variable "tags" {
  type    = map(string)
  default = { ManagedBy = "terraform", Purpose = "tf-bootstrap" }
}
