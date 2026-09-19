terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.60" }
  }
}

# Encrypted with a CMK whose policy lets cloudwatch.amazonaws.com publish
# (the AWS-managed aws/sns key cannot be used by CloudWatch alarms). Shared by
# every API on the platform: their CloudWatch alarms name this topic ARN
# (published at /platform/<env>/alarms/topic_arn) as their alarm action.
resource "aws_sns_topic" "alarms" {
  name              = "${var.name}-alarms"
  kms_master_key_id = var.kms_key_arn
  tags              = var.tags
}

# CloudWatch alarms in this account may publish (the alarms live in the API
# stacks, i.e. other Terraform states, so the topic policy must allow it).
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "topic" {
  statement {
    sid     = "CloudWatchAlarmsPublish"
    actions = ["sns:Publish"]
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
    resources = [aws_sns_topic.alarms.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "alarms" {
  arn    = aws_sns_topic.alarms.arn
  policy = data.aws_iam_policy_document.topic.json
}

# Optional email subscription so alarms actually page someone. Provide
# alarm_email to enable; the address must confirm the subscription once.
resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email == null ? 0 : 1
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}
