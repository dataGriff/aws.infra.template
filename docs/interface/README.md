# The platform interface

Everything an API stack may consume from the platform is an **SSM Parameter Store** parameter
under `/<platform_name>/<env>/` (default `/platform/dev/`, `/platform/staging/`,
`/platform/prod/`). This table is the contract; `interface/version` is bumped on any breaking
change (rename, removal, semantic change). Adding a parameter is not breaking.

Published by `terraform/platform/main.tf` (`local.interface_always` / `local.interface_optional`)
through `terraform/modules/ssm-interface`; verified after every deploy by
`task interface:verify` (`scripts/interface-verify.sh` lists the always-present set).

| Name                              | Type       | Present                    | Value                                                             |
| --------------------------------- | ---------- | -------------------------- | ----------------------------------------------------------------- |
| `interface/version`               | String     | always                     | `"1"` — the interface version this platform publishes             |
| `network/vpc_id`                  | String     | always                     | VPC id                                                            |
| `network/vpc_cidr`                | String     | always                     | VPC CIDR (for security-group rules)                               |
| `network/private_subnet_ids`      | StringList | always                     | Private subnet ids (Lambda, RDS, proxies)                         |
| `network/public_subnet_ids`       | StringList | always                     | Public subnet ids                                                 |
| `network/dynamodb_prefix_list_id` | String     | always                     | Managed prefix list of the DynamoDB gateway endpoint              |
| `network/nat_enabled`             | String     | always                     | `"true"`/`"false"` — whether private subnets have internet egress |
| `network/egress_ip`               | String     | `enable_egress_static_ip`  | The stable egress IP                                              |
| `kms/data_key_arn`                | String     | always                     | CMK for data at rest (databases, secrets, tables)                 |
| `kms/ops_key_arn`                 | String     | always                     | CMK for logs, alarm topic, Lambda environment                     |
| `cognito/user_pool_id`            | String     | always                     | User pool id                                                      |
| `cognito/user_pool_arn`           | String     | always                     | User pool ARN (API Gateway Cognito authorizer)                    |
| `cognito/issuer`                  | String     | always                     | `https://cognito-idp.<region>.amazonaws.com/<pool id>`            |
| `cognito/app_client_id`           | String     | always                     | Public app client (code + PKCE)                                   |
| `cognito/hosted_ui_domain`        | String     | always                     | Hosted UI domain prefix                                           |
| `cognito/test_client_id`          | String     | `enable_test_client`       | Password-auth client for CI (dev/staging only)                    |
| `waf/web_acl_arn`                 | String     | `enable_waf`               | Regional web ACL to associate API stages with                     |
| `dns/hosted_zone_id`              | String     | `dns_enabled`              | Route53 zone of `base_domain`                                     |
| `dns/base_domain`                 | String     | `dns_enabled`              | e.g. `dev.example.com`; APIs get `<service>.<base_domain>`        |
| `dns/certificate_arn`             | String     | `dns_enabled`              | Validated regional wildcard certificate `*.<base_domain>`         |
| `alarms/topic_arn`                | String     | always                     | SNS topic every API's alarms publish to                           |
| `apigw/cloudwatch_role_arn`       | String     | always                     | The account-wide API Gateway logging role (reference only)        |
| `ingress/static_ips`              | StringList | `enable_ingress_static_ip` | The two Global Accelerator anycast IPs                            |

## Token claims

The identity half of the interface: what an access token issued by the platform's user pool
carries. Every API authorizes on these, so they are as much a contract as the parameters above;
the API contract template documents the same shape from the consumer's side
(`access_token_claims` in `aws.contract.template`), and changing them is an interface bump.

| Claim              | Source                                                                   | Type                                | Present                                  |
| ------------------ | ------------------------------------------------------------------------ | ----------------------------------- | ---------------------------------------- |
| `sub`              | Cognito                                                                  | string (stable user id)             | always                                   |
| `custom:tenant_id` | the user's `custom:tenant_id` attribute, copied by the pre-token trigger | string, 1–256 chars                 | always (trigger fails closed without it) |
| `roles`            | the user's group memberships, added by the pre-token trigger             | string: JSON-encoded array of names | when the user is in ≥ 1 group            |
| `cognito:groups`   | Cognito                                                                  | array of strings                    | when Cognito includes it                 |

- Both the **access** and **id** tokens carry the custom claims (V2 trigger, `packages/cognito-pretoken`).
- `roles` is JSON-encoded so group names containing separators survive the API Gateway
  authorizer's flattening of array claims into `"[a b]"`.
- The `admin` group is the conventional administrator role; APIs may define others.
- Standard claims (`iss`, `aud`/`client_id`, `exp`, `token_use`, …) are verified by each API's
  gateway authorizer against `cognito/user_pool_arn` and are not part of this table.

## Consuming it from an API stack

```hcl
data "aws_ssm_parameter" "required" {
  for_each = toset(["interface/version", "network/vpc_id", "network/private_subnet_ids", "kms/ops_key_arn"])
  name     = "/platform/${var.env}/${each.key}"
}

locals {
  private_subnet_ids = split(",", data.aws_ssm_parameter.required["network/private_subnet_ids"].value)
}

resource "terraform_data" "interface_version" {
  lifecycle {
    precondition {
      condition     = data.aws_ssm_parameter.required["interface/version"].value == "1"
      error_message = "This stack was written against platform interface version 1."
    }
  }
}
```

Read optional parameters only when your own flag is on (`count = var.enable_waf ? 1 : 0`), so a
missing feature fails at plan time with a clear message. The service deploy role created by the
bootstrap may read only `/<platform_name>/<env>/*` for its environment and is explicitly denied
any write under `/<platform_name>/*`: only the platform's own deploy publishes the interface.

## Changing the interface

1. Additive change (new parameter, new optional claim): add it to `local.interface_always` /
   `_optional` (or the trigger), this document and, if always-present,
   `scripts/interface-verify.sh` + the `dev_defaults` test.
2. Breaking change (rename/removal, a claim's name, type or encoding): do the above, bump
   `interface_version` (`terraform/platform/variables.tf`), and coordinate with every API stack's
   `platform_interface_version` and every contract's `access_token_claims` before deploying.
