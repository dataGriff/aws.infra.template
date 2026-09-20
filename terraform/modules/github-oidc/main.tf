terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.60" }
  }
}

# --- GitHub Actions OIDC: the deploy trust boundary, in code ------------------
# One role per (repository, environment). GitHub's OIDC token `sub` for a job
# running under a GitHub Environment is `repo:<owner>/<repo>:environment:<name>`,
# so a role can only be assumed by THAT repository, from a job bound to THAT
# environment (which is where the protection rules / required reviewers live).
# Nothing else — not a fork, not another branch without the environment — matches.
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_provider ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
  # GitHub's provider is validated by AWS via its trusted root CAs; the
  # thumbprint is still required by the API.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  client_id_list  = ["sts.amazonaws.com"]
  tags            = var.tags
}

# The provider is an account singleton; reuse it when another stack owns it.
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  partition    = data.aws_partition.current.partition
  account_id   = data.aws_caller_identity.current.account_id
  provider_arn = var.create_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

data "aws_iam_policy_document" "trust" {
  for_each = var.roles
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${each.value.github_repository}:environment:${each.value.environment}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  for_each             = var.roles
  name                 = each.key
  assume_role_policy   = data.aws_iam_policy_document.trust[each.key].json
  max_session_duration = 3600
  tags                 = merge(var.tags, { Environment = each.value.environment, Repository = each.value.github_repository })
}

# Platform roles create IAM roles, KMS keys, VPCs, Cognito, the OIDC provider
# itself... so they keep broad rights; the trust policy above is what keeps
# them from being assumed by anyone but the intended workflow.
resource "aws_iam_role_policy_attachment" "admin" {
  for_each   = { for k, r in var.roles : k => r if r.admin }
  role       = aws_iam_role.deploy[each.key].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AdministratorAccess"
}

# Service roles deploy one API: everything except IAM (PowerUserAccess), plus
# IAM scoped to roles/policies carrying the service's own name prefix.
resource "aws_iam_role_policy_attachment" "poweruser" {
  for_each   = { for k, r in var.roles : k => r if !r.admin }
  role       = aws_iam_role.deploy[each.key].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/PowerUserAccess"
}

data "aws_iam_policy_document" "scoped_iam" {
  for_each = { for k, r in var.roles : k => r if !r.admin }
  statement {
    sid = "ServiceRolesAndPolicies"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole", "iam:UpdateRoleDescription",
      "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole", "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PassRole",
      "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy", "iam:GetPolicyVersion",
      "iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:ListPolicyVersions",
      "iam:TagPolicy", "iam:UntagPolicy",
    ]
    resources = [
      "arn:${local.partition}:iam::${local.account_id}:role/${each.value.iam_name_prefix}*",
      "arn:${local.partition}:iam::${local.account_id}:policy/${each.value.iam_name_prefix}*",
    ]
  }
  # (iam:ListRoles and iam:CreateServiceLinkedRole — needed by RDS/API Gateway —
  # are already granted by PowerUserAccess.)
  statement {
    sid       = "PlatformInterface"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath", "ssm:DescribeParameters"]
    resources = ["arn:${local.partition}:ssm:*:${local.account_id}:parameter${each.value.ssm_prefix}/*"]
  }
}

resource "aws_iam_role_policy" "scoped_iam" {
  for_each = data.aws_iam_policy_document.scoped_iam
  name     = "scoped-iam-and-platform-interface"
  role     = aws_iam_role.deploy[each.key].id
  policy   = each.value.json
}

# Every role can touch ONLY its own state backend (bucket, lock table and KMS
# key). This is the isolation the per-env, per-repo split buys us.
data "aws_iam_policy_document" "state_access" {
  for_each = var.roles
  statement {
    actions   = ["s3:ListBucket"]
    resources = [each.value.state_bucket_arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${each.value.state_bucket_arn}/*"]
  }
  statement {
    # DescribeTable: the S3 backend validates the lock table on every init.
    actions   = ["dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [each.value.lock_table_arn]
  }
  statement {
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey"]
    resources = [each.value.state_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "state_access" {
  for_each = var.roles
  name     = "terraform-state"
  role     = aws_iam_role.deploy[each.key].id
  policy   = data.aws_iam_policy_document.state_access[each.key].json
}
