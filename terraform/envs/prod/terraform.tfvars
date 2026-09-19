region        = "eu-west-2"
platform_name = "platform"

# Safety guard: a wrong active AWS profile can never apply prod into the wrong
# account. Update when prod moves to its own account.
allowed_account_ids = ["018648229057"]

vpc_cidr = "10.2.0.0/16"

# The platform REFUSES to plan prod without: alarm_email, enable_waf = true,
# https callback/logout URLs, deletion_protection and no password-auth test
# client (see terraform/platform/variables.tf validations).
enable_waf               = true
enable_egress_static_ip  = false
enable_ingress_static_ip = false
dns_enabled              = false
# base_domain    = "example.com"
# hosted_zone_id = "Z0123456789ABCDEFGHIJ"

# REQUIRED in prod — replace before the first plan:
# alarm_email = "alerts@example.com"
callback_urls = ["https://app.example.com/callback"]
logout_urls   = ["https://app.example.com/"]

# See envs/dev/terraform.tfvars: only one env per account+region manages this.
manage_apigw_account_settings = false
