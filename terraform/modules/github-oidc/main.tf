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

# --- Workload permissions boundary ------------------------------------------
# A service deploy role may create IAM roles for its workloads (Lambda, RDS
# Proxy, ...). Without a cap it could attach AdministratorAccess to such a role
# and pass it to a Lambda — an escape from its own scope. So every role a
# service creates or re-policies MUST carry this boundary (enforced by the
# iam:PermissionsBoundary conditions below), and the boundary itself never
# grants IAM. Effective workload permissions = its policies ∩ this allowlist.
data "aws_iam_policy_document" "workload_boundary" {
  #checkov:skip=CKV_AWS_356:A permissions boundary is a ceiling, not a grant — it must name the whole action space the workload policies may use; the roles' own policies scope resources
  #checkov:skip=CKV_AWS_290:Same — a boundary intentionally lists write actions on "*"; effective access is the intersection with the role's scoped policy
  #checkov:skip=CKV_AWS_355:Same
  for_each = { for k, r in var.roles : k => r if !r.admin }
  statement {
    sid       = "WorkloadAllowlist"
    actions   = var.workload_boundary_actions
    resources = ["*"]
  }
  statement {
    sid    = "DenyWritesToPlatformInterface"
    effect = "Deny"
    actions = [
      "ssm:PutParameter", "ssm:DeleteParameter", "ssm:DeleteParameters",
      "ssm:LabelParameterVersion", "ssm:UnlabelParameterVersion",
      "ssm:PutResourcePolicy", "ssm:DeleteResourcePolicy",
    ]
    resources = ["arn:${local.partition}:ssm:*:${local.account_id}:parameter${each.value.protected_ssm_prefix}/*"]
  }
}

resource "aws_iam_policy" "workload_boundary" {
  for_each    = data.aws_iam_policy_document.workload_boundary
  name        = "${var.roles[each.key].iam_name_prefix}workload-boundary"
  description = "Permissions boundary every IAM role created by ${each.key} must carry"
  policy      = each.value.json
  tags        = var.tags
}

data "aws_iam_policy_document" "scoped_iam" {
  for_each = { for k, r in var.roles : k => r if !r.admin }
  # Creating a role or giving it permissions only works WITH the boundary.
  statement {
    sid       = "CreateBoundedRoles"
    actions   = ["iam:CreateRole", "iam:PutRolePolicy", "iam:AttachRolePolicy", "iam:PutRolePermissionsBoundary"]
    resources = ["arn:${local.partition}:iam::${local.account_id}:role/${each.value.iam_name_prefix}*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [aws_iam_policy.workload_boundary[each.key].arn]
    }
  }
  statement {
    sid = "ManageServiceRoles"
    actions = [
      "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole", "iam:UpdateRoleDescription",
      "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole", "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
      "iam:DeleteRolePolicy", "iam:GetRolePolicy", "iam:DetachRolePolicy", "iam:PassRole",
    ]
    resources = ["arn:${local.partition}:iam::${local.account_id}:role/${each.value.iam_name_prefix}*"]
  }
  statement {
    sid = "ManageServicePolicies"
    actions = [
      "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy", "iam:GetPolicyVersion",
      "iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:ListPolicyVersions",
      "iam:TagPolicy", "iam:UntagPolicy",
    ]
    resources = ["arn:${local.partition}:iam::${local.account_id}:policy/${each.value.iam_name_prefix}*"]
  }
  # The boundary is the platform's: a service may read it, never remove or edit it.
  statement {
    sid       = "DenyBoundaryTampering"
    effect    = "Deny"
    actions   = ["iam:DeleteRolePermissionsBoundary"]
    resources = ["arn:${local.partition}:iam::${local.account_id}:role/${each.value.iam_name_prefix}*"]
  }
  statement {
    sid       = "DenyBoundaryEdits"
    effect    = "Deny"
    actions   = ["iam:CreatePolicyVersion", "iam:DeletePolicy", "iam:DeletePolicyVersion", "iam:SetDefaultPolicyVersion"]
    resources = [aws_iam_policy.workload_boundary[each.key].arn]
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

# PowerUserAccess allows every SSM action, so without this a service could
# overwrite or delete the platform's published interface. An explicit deny on
# the whole platform namespace (every environment) beats that allow; reads are
# granted above and stay untouched.
data "aws_iam_policy_document" "protect_platform_interface" {
  for_each = { for k, r in var.roles : k => r if !r.admin }
  statement {
    sid    = "DenyWritesToPlatformInterface"
    effect = "Deny"
    actions = [
      "ssm:PutParameter", "ssm:DeleteParameter", "ssm:DeleteParameters",
      "ssm:LabelParameterVersion", "ssm:UnlabelParameterVersion",
      "ssm:PutResourcePolicy", "ssm:DeleteResourcePolicy",
      "ssm:AddTagsToResource", "ssm:RemoveTagsFromResource",
    ]
    resources = ["arn:${local.partition}:ssm:*:${local.account_id}:parameter${each.value.protected_ssm_prefix}/*"]
  }
}

resource "aws_iam_role_policy" "protect_platform_interface" {
  for_each = data.aws_iam_policy_document.protect_platform_interface
  name     = "protect-platform-interface"
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
    # DescribeKey: the deploy tasks resolve the derived alias to the key ARN,
    # which the bucket policy requires on every write.
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [each.value.state_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "state_access" {
  for_each = var.roles
  name     = "terraform-state"
  role     = aws_iam_role.deploy[each.key].id
  policy   = data.aws_iam_policy_document.state_access[each.key].json
}
