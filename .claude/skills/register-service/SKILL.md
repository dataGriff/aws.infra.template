---
name: register-service
description: Register a new API service on this platform (state backend + scoped GitHub OIDC deploy role per environment), wire its repo, and adopt/re-skin the platform template itself (platform name, account, domains).
---

# Register a service / adopt the platform

The platform is one-per-account; API services deploy onto it and are **registered here**, never
self-bootstrapped. Work in a branch; small commits; `task ci` green before handing back.

## A. Adopt the platform template (first time)

1. **Name it**: `platform_name` in `terraform/bootstrap/variables.tf` (default) and each
   `terraform/envs/*/terraform.tfvars`. This becomes the SSM prefix `/<platform_name>/<env>/` —
   tell every API (`platform_name` in their stack variables).
2. **Point the trust at your repo**: `github_repository` default in the bootstrap variables.
3. **Per env tfvars**: `allowed_account_ids`, `vpc_cidr` (non-overlapping per env in one
   account), `callback_urls`/`logout_urls`, `alarm_email` (required in prod), opt-ins
   (`enable_waf` — mandatory in prod, `dns_enabled` + `base_domain` + `hosted_zone_id`,
   `enable_egress_static_ip`, `enable_ingress_static_ip`), `manage_apigw_account_settings`
   (true in exactly one env per account+region).
4. **Claims**: if your tenancy model differs, edit `packages/cognito-pretoken/src/handler.ts` and
   the `schema` attribute in `terraform/modules/cognito/main.tf` (pool replacement — do it before
   users exist), and tell the API template (`auth/claims.ts`).
5. `task ci`, then `task tf:bootstrap GITHUB_REPOSITORY=<owner/repo>` with admin credentials and
   wire `AWS_DEPLOY_ROLE_ARN` per GitHub Environment (docs/operations).

## B. Register an API service

1. Add `{ name = "<service_name>", github_repository = "<owner>/<repo>" }` to `services`
   (`terraform/bootstrap/variables.tf`). `name` = the API repo's `service_name`; lower-case
   kebab-case.
2. Re-run `task tf:bootstrap GITHUB_REPOSITORY=…`; copy
   `service_deploy_role_arns["<service_name>"][<env>]` into the service repo's GitHub Environments
   as `AWS_DEPLOY_ROLE_ARN`.
3. Confirm the env publishes what the service needs: `enable_waf` if it associates the WAF,
   `dns_enabled` if it wants `<service_name>.<base_domain>`, `enable_test_client` for its CI fuzz
   runs.
4. Deploy the platform env before the service's first deploy.

## C. Change the interface

Additive: add to `local.interface_always`/`_optional` in `terraform/platform/main.tf`, the table in
`docs/interface/README.md`, `scripts/interface-verify.sh` (if always-present) and the
`dev_defaults` test. Breaking: also bump `interface_version` and coordinate with every API.

## Checklist

- [ ] `platform_name`, `github_repository`, tfvars per env set
- [ ] `services` lists every API repo
- [ ] `task ci` green (fmt, validate, tflint, terraform test, trivy, checkov, unit)
- [ ] bootstrap applied; `AWS_DEPLOY_ROLE_ARN` wired in every repo's Environments
- [ ] `docs/interface` and `interface-verify.sh` match `platform/main.tf`
