terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.60" }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# --- Customer-managed keys with explicit policies -----------------------------
# Two keys per environment, shared by every API on the platform:
#   data: database storage, Performance Insights, credential secrets, tables.
#         Callers reach it through the services (grants), so the policy only
#         needs the account root; IAM policies on the roles do the rest.
#   ops:  CloudWatch log groups, the alarm SNS topic and Lambda environment
#         variables. CloudWatch Logs and CloudWatch Alarms encrypt/decrypt with
#         it as services, so they need explicit grants in the key policy.
data "aws_iam_policy_document" "data" {
  #checkov:skip=CKV_AWS_109:Standard AWS key policy — the account root principal must keep kms:* or the key becomes unmanageable; access is delegated through IAM
  #checkov:skip=CKV_AWS_111:Standard AWS key policy — the account root principal must keep kms:* or the key becomes unmanageable; access is delegated through IAM
  #checkov:skip=CKV_AWS_356:Standard AWS key policy — resources must be "*" inside a key policy (it applies to the key itself)
  statement {
    sid       = "AccountAdmin"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_kms_key" "data" {
  description             = "${var.name} data encryption (databases + credentials + tables of every API)"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.data.json
  tags                    = var.tags
}

resource "aws_kms_alias" "data" {
  name          = "alias/${var.name}-data"
  target_key_id = aws_kms_key.data.key_id
}

data "aws_iam_policy_document" "ops" {
  #checkov:skip=CKV_AWS_109:Standard AWS key policy — the account root principal must keep kms:* or the key becomes unmanageable; access is delegated through IAM
  #checkov:skip=CKV_AWS_111:Standard AWS key policy — the account root principal must keep kms:* or the key becomes unmanageable; access is delegated through IAM
  #checkov:skip=CKV_AWS_356:Standard AWS key policy — resources must be "*" inside a key policy (it applies to the key itself)
  statement {
    sid       = "AccountAdmin"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
  statement {
    sid = "CloudWatchLogs"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${data.aws_partition.current.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:*"]
    }
  }
  statement {
    sid       = "CloudWatchAlarmsToSns"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "ops" {
  description             = "${var.name} operational encryption (logs, alarms topic, Lambda environment of every API)"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.ops.json
  tags                    = var.tags
}

resource "aws_kms_alias" "ops" {
  name          = "alias/${var.name}-ops"
  target_key_id = aws_kms_key.ops.key_id
}
