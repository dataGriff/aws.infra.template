region        = "eu-west-2"
platform_name = "platform"

# Safety guard: Terraform refuses to run if your active AWS credentials point at a
# different account. Update when this env moves to its own account.
allowed_account_ids = ["018648229057"]

vpc_cidr = "10.0.0.0/16"

# Opt-ins (default off). Flip on and re-plan to add:
enable_waf               = false
enable_egress_static_ip  = false
enable_ingress_static_ip = false
dns_enabled              = false
# base_domain    = "dev.example.com"
# hosted_zone_id = "Z0123456789ABCDEFGHIJ"
# alarm_email    = "alerts@example.com"

# Nothing is VPC-attached in dev yet, and PrivateLink bills per endpoint PER AZ
# (~$7.30/month each — five endpoints across two AZs is ~$75/month for AWS API
# reachability from empty private subnets). Add back what a VPC-attached workload
# actually calls when one arrives (usually logs + sts + kms), optionally with
# endpoint_az_count = 1. staging and prod keep the full set.
interface_endpoints = []

# Shorter log retention than the 365-day prod default.
log_retention_days = 14

# Browser clients: the hosted-UI redirect URIs of your front end(s).
callback_urls = ["http://localhost:3000/callback"]
logout_urls   = ["http://localhost:3000/"]

# The account-wide API Gateway logging role is managed from ONE env per
# account+region. If dev/staging/prod share an account, keep true here and set
# false in the others.
manage_apigw_account_settings = true
