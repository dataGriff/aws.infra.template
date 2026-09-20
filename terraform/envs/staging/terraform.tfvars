region        = "eu-west-2"
platform_name = "platform"

# Safety guard: Terraform refuses to run if your active AWS credentials point at a
# different account. Update when this env moves to its own account.
allowed_account_ids = ["018648229057"]

# A second VPC in the same account must not overlap dev's.
vpc_cidr = "10.1.0.0/16"

# Mirrors prod topology: WAF on.
enable_waf               = true
enable_egress_static_ip  = false
enable_ingress_static_ip = false
dns_enabled              = false
# base_domain    = "staging.example.com"
# hosted_zone_id = "Z0123456789ABCDEFGHIJ"
# alarm_email    = "alerts@example.com"

# Shorter log retention than the 365-day prod default.
log_retention_days = 30

callback_urls = ["https://staging.app.example.com/callback"]
logout_urls   = ["https://staging.app.example.com/"]

# See envs/dev/terraform.tfvars: only one env per account+region manages this.
manage_apigw_account_settings = false
