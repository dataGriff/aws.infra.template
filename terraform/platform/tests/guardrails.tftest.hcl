# Plan-time tests of the platform's guardrails and published interface.
# Providers are mocked, so this runs without credentials or network
# (terraform test, in `task tf:test`).

mock_provider "aws" {
  override_data {
    target = data.aws_availability_zones.available
    values = { names = ["eu-west-2a", "eu-west-2b", "eu-west-2c"] }
  }
  # The provider validates policy JSON at plan time; a mocked random string fails.
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws", dns_suffix = "amazonaws.com" }
  }
}
mock_provider "random" {}
mock_provider "archive" {}

variables {
  platform_name     = "platform"
  region            = "eu-west-2"
  pretoken_dist_dir = "../../../packages/cognito-pretoken/dist"
}

# --- prod refuses unsafe inputs ----------------------------------------------
run "prod_refuses_missing_alarm_email" {
  command = plan
  variables {
    env                 = "prod"
    deletion_protection = true
    enable_waf          = true
    callback_urls       = ["https://app.example.com/callback"]
    logout_urls         = ["https://app.example.com/"]
  }
  expect_failures = [var.alarm_email]
}

run "prod_refuses_localhost_callbacks" {
  command = plan
  variables {
    env                 = "prod"
    deletion_protection = true
    enable_waf          = true
    alarm_email         = "ops@example.com"
    callback_urls       = ["http://localhost:3000/callback"]
    logout_urls         = ["https://app.example.com/"]
  }
  expect_failures = [var.callback_urls]
}

run "prod_refuses_test_client_and_waf_off" {
  command = plan
  variables {
    env                 = "prod"
    deletion_protection = true
    enable_waf          = false
    enable_test_client  = true
    alarm_email         = "ops@example.com"
    callback_urls       = ["https://app.example.com/callback"]
    logout_urls         = ["https://app.example.com/"]
  }
  expect_failures = [var.enable_waf, var.enable_test_client]
}

run "prod_refuses_without_deletion_protection" {
  command = plan
  variables {
    env                 = "prod"
    deletion_protection = false
    enable_waf          = true
    alarm_email         = "ops@example.com"
    callback_urls       = ["https://app.example.com/callback"]
    logout_urls         = ["https://app.example.com/"]
  }
  expect_failures = [var.deletion_protection]
}

run "dns_requires_zone_and_domain" {
  command = plan
  variables {
    env         = "dev"
    dns_enabled = true
  }
  expect_failures = [var.dns_enabled]
}

# --- a hardened prod plans, with the protections and the interface in the plan --
run "prod_hardened" {
  command = plan
  variables {
    env                 = "prod"
    deletion_protection = true
    enable_waf          = true
    alarm_email         = "ops@example.com"
    callback_urls       = ["https://app.example.com/callback"]
    logout_urls         = ["https://app.example.com/"]
    dns_enabled         = true
    base_domain         = "example.com"
    hosted_zone_id      = "Z0123456789ABCDEFGHIJ"
  }
  assert {
    condition     = module.cognito.deletion_protection == "ACTIVE"
    error_message = "prod user pool must carry deletion protection"
  }
  assert {
    condition     = module.cognito.prevent_user_existence_errors == "ENABLED"
    error_message = "app client must not leak user existence"
  }
  assert {
    condition     = module.cognito.test_client_enabled == false
    error_message = "no password-auth test client in prod"
  }
  assert {
    condition     = length(module.waf) == 1 && length(module.dns) == 1
    error_message = "WAF and DNS must exist when enabled"
  }
  assert {
    condition     = module.interface.names["waf/web_acl_arn"] == "/platform/prod/waf/web_acl_arn"
    error_message = "the WAF ACL must be published when enable_waf is true"
  }
  assert {
    condition     = module.interface.names["dns/certificate_arn"] == "/platform/prod/dns/certificate_arn"
    error_message = "the wildcard certificate must be published when dns_enabled is true"
  }
  assert {
    condition     = !contains(keys(module.interface.names), "cognito/test_client_id")
    error_message = "prod must not publish a test client id"
  }
}

run "prod_refuses_trimmed_endpoints" {
  command = plan
  variables {
    env                 = "prod"
    deletion_protection = true
    enable_waf          = true
    alarm_email         = "ops@example.com"
    callback_urls       = ["https://app.example.com/callback"]
    logout_urls         = ["https://app.example.com/"]
    interface_endpoints = ["logs"]
    endpoint_az_count   = 1
  }
  expect_failures = [var.interface_endpoints, var.endpoint_az_count]
}

# --- dev may trade endpoint reachability for cost, without moving the interface ---
run "dev_can_drop_endpoints" {
  command = plan
  variables {
    env                 = "dev"
    interface_endpoints = []
  }
  assert {
    condition     = length(module.network.interface_endpoints) == 0
    error_message = "dev must be able to create no interface endpoints at all"
  }
  assert {
    condition     = module.interface.names["network/private_subnet_ids"] == "/platform/dev/network/private_subnet_ids"
    error_message = "dropping endpoints must not change the published interface"
  }
}

run "endpoint_az_count_shrinks_the_billed_enis" {
  command = plan
  variables {
    env               = "dev"
    endpoint_az_count = 1
  }
  assert {
    condition     = alltrue([for azs in values(module.network.interface_endpoints) : azs == 1])
    error_message = "each endpoint must have an ENI in exactly one AZ when endpoint_az_count = 1"
  }
}

# --- dev defaults: the always-present interface, nothing optional -----------------
run "dev_defaults" {
  command = plan
  variables {
    env = "dev"
  }
  assert {
    condition = alltrue([
      for k in [
        "interface/version", "network/vpc_id", "network/vpc_cidr", "network/private_subnet_ids",
        "network/public_subnet_ids", "network/dynamodb_prefix_list_id", "network/nat_enabled",
        "kms/data_key_arn", "kms/ops_key_arn", "cognito/user_pool_id", "cognito/user_pool_arn",
        "cognito/issuer", "cognito/app_client_id", "cognito/hosted_ui_domain", "alarms/topic_arn",
        "apigw/cloudwatch_role_arn",
      ] : module.interface.names[k] == "/platform/dev/${k}"
    ])
    error_message = "every always-present interface parameter must be published under /platform/dev/"
  }
  assert {
    condition     = length(setintersection(keys(module.interface.names), ["waf/web_acl_arn", "dns/base_domain", "network/egress_ip", "ingress/static_ips", "cognito/test_client_id"])) == 0
    error_message = "optional parameters must not be published when their feature is off"
  }
  assert {
    condition     = module.network.nat_enabled == false && length(module.waf) == 0
    error_message = "NAT and WAF are opt-in"
  }
}

run "interface_types" {
  command = plan
  variables {
    env                = "dev"
    enable_test_client = true
  }
  assert {
    condition     = module.interface.names["cognito/test_client_id"] == "/platform/dev/cognito/test_client_id"
    error_message = "the test client id is published when enabled"
  }
}

run "static_egress_opens_nat_and_publishes_ip" {
  command = plan
  variables {
    env                     = "dev"
    enable_egress_static_ip = true
  }
  assert {
    condition     = module.network.nat_enabled == true
    error_message = "the NAT gateway must exist when static egress is enabled"
  }
  assert {
    condition     = module.interface.names["network/egress_ip"] == "/platform/dev/network/egress_ip"
    error_message = "the egress IP must be published when static egress is enabled"
  }
}
