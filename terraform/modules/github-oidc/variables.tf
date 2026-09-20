variable "create_provider" {
  type        = bool
  default     = true
  description = "Create the account's GitHub OIDC provider (set false if another stack already owns it; it is then looked up)."
}
variable "roles" {
  description = "Deploy roles to create, keyed by role name. admin = AdministratorAccess (platform); otherwise PowerUserAccess + IAM scoped to iam_name_prefix + read of the platform interface under ssm_prefix, with writes under protected_ssm_prefix (the whole platform namespace) explicitly denied."
  type = map(object({
    github_repository    = string
    environment          = string
    admin                = bool
    state_bucket_arn     = string
    lock_table_arn       = string
    state_kms_key_arn    = string
    iam_name_prefix      = optional(string, "")
    ssm_prefix           = optional(string, "/platform")
    protected_ssm_prefix = optional(string, "/platform")
  }))
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "workload_boundary_actions" {
  type        = list(string)
  description = "Ceiling for every IAM role a service deploy role creates (Lambda, RDS Proxy, ...): the action namespaces an API workload may use. Extend here (a platform change) when a service needs more; IAM is never included."
  default = [
    "logs:*", "xray:*", "cloudwatch:*",
    "secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret",
    "rds-db:connect", "rds:Describe*",
    "dynamodb:*", "sqs:*", "sns:Publish", "events:PutEvents", "states:*",
    "s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket",
    "s3:GetBucketLocation", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts",
    "kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey*", "kms:DescribeKey",
    "ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath", "ssm:DescribeParameters",
    "lambda:InvokeFunction", "execute-api:Invoke",
    "ec2:CreateNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DeleteNetworkInterface",
    "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups", "ec2:DescribeVpcs",
    "ec2:AssignPrivateIpAddresses", "ec2:UnassignPrivateIpAddresses",
    "sts:GetCallerIdentity",
  ]
}
