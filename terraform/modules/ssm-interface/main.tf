terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.60" }
  }
}

# The platform's published interface: one SSM parameter per value an API stack
# may consume, under <prefix>/ (e.g. /platform/dev/network/vpc_id). API stacks
# read these with data "aws_ssm_parameter" and never touch platform state.
# Names, types and semantics are documented in docs/interface and versioned by
# <prefix>/interface/version.
resource "aws_ssm_parameter" "this" {
  #checkov:skip=CKV_AWS_337:Values are resource identifiers (ARNs, ids, CIDRs) that are not secret; String/StringList keep them readable by every service deploy role without a KMS grant. Secrets never go through this interface.
  #checkov:skip=CKV2_AWS_34:Same as above — non-secret identifiers, SecureString not required
  for_each    = var.parameters
  name        = "${var.prefix}/${each.key}"
  type        = each.value.type
  value       = each.value.value
  description = each.value.description
  tier        = "Standard"
  tags        = var.tags
}
