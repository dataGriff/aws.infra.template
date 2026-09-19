terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.60" }
  }
}

data "aws_partition" "current" {}

# API Gateway writes access/execution logs through ONE account-wide role per
# region. Several stacks in the same account/region must not all manage it
# (each apply would flip the role and a destroy would remove it from under the
# others), so the platform owns it and the API stacks only reference it.
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudwatch" {
  name_prefix        = "${var.name}-apigw-cw-"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.cloudwatch.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "this" {
  count               = var.manage_account_settings ? 1 : 0
  cloudwatch_role_arn = aws_iam_role.cloudwatch.arn
}
