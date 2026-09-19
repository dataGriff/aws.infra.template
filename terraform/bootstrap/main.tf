terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.60" }
  }
  # Uses a local backend — this creates the remote backends everything else uses.
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# One-time-per-account bootstrap of the deploy trust boundary and state storage:
#
#   * the platform's own state backend + deploy role, per environment
#   * every registered API SERVICE's state backend + deploy role, per environment
#     (so an API repo never bootstraps anything — it is registered here)
#   * the account's GitHub OIDC provider
#
# Backend names are DERIVED (<name>-tfstate-<env>-<account> / <name>-tflock-<env>
# / alias/<name>-tfstate-<env>) so a deploy only needs the name + env, and each
# deploy role is scoped to ONLY its own backend: dev cannot read or write
# staging/prod state, and an API cannot read the platform's.
locals {
  account_id = data.aws_caller_identity.current.account_id

  # Every (owner, env) pair that gets a backend + role. The platform is one
  # owner; each service another.
  owners = merge(
    { (var.platform_name) = { github_repository = var.github_repository, admin = true } },
    { for s in var.services : s.name => { github_repository = s.github_repository, admin = false } },
  )
  backends = {
    for pair in setproduct(keys(local.owners), var.deploy_environments) :
    "${pair[0]}/${pair[1]}" => { owner = pair[0], env = pair[1] }
  }
}

module "backend" {
  source       = "../modules/tf-backend"
  for_each     = local.backends
  state_bucket = "${each.value.owner}-tfstate-${each.value.env}-${local.account_id}"
  lock_table   = "${each.value.owner}-tflock-${each.value.env}"
  kms_alias    = "${each.value.owner}-tfstate-${each.value.env}"
  tags         = merge(var.tags, { Owner = each.value.owner, Environment = each.value.env })
}

module "github_oidc" {
  source          = "../modules/github-oidc"
  create_provider = var.create_github_oidc
  roles = {
    for key, b in local.backends :
    "${var.deploy_role_prefix}-${b.owner}-${b.env}" => {
      github_repository = local.owners[b.owner].github_repository
      environment       = b.env
      admin             = local.owners[b.owner].admin
      state_bucket_arn  = module.backend[key].state_bucket_arn
      lock_table_arn    = module.backend[key].lock_table_arn
      state_kms_key_arn = module.backend[key].kms_key_arn
      # A service's IAM roles/policies are named <service>-<env>-...; the
      # platform publishes its interface under /<platform_name>/<env>/.
      iam_name_prefix = "${b.owner}-${b.env}-"
      ssm_prefix      = "/${var.platform_name}/${b.env}"
    }
  }
  tags = var.tags
}
