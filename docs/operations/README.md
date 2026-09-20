# Operations

Runbooks for bootstrapping an account, registering API services and operating the platform.

## First-time setup (bootstrap)

Run this **once per AWS account**, before any deploy of the platform or of an API. It creates, per
environment:

- the **platform's** isolated state backend (S3 bucket + KMS key + DynamoDB lock table) and its
  GitHub OIDC deploy role (administrator; trust scoped to `repo:<this repo>:environment:<env>`);
- for **every registered service** (`terraform/bootstrap/variables.tf` → `services`): its own state
  backend, named from the service's `service_name`, and a deploy role trusting
  `repo:<service repo>:environment:<env>` with `PowerUserAccess` + IAM scoped to
  `<service>-<env>-*` + that backend + read of `/<platform_name>/<env>/*`;
- the account's GitHub OIDC provider (`create_github_oidc = false` if it already exists).

It uses a **local** backend (the chicken-and-egg step that creates the remote ones), so its state
lives on disk in `terraform/bootstrap` — re-run it only when backends, roles or the service list
change. Backend names are **derived**, so nobody picks a globally-unique bucket by hand:

| Resource   | Name                                 |
| ---------- | ------------------------------------ |
| State S3   | `<owner>-tfstate-<env>-<account_id>` |
| Lock table | `<owner>-tflock-<env>`               |
| KMS alias  | `alias/<owner>-tfstate-<env>`        |

`<owner>` is `platform_name` for the platform and `service_name` for each API — the API repo's
`task tf:plan` recomputes exactly these names.

- **Prerequisites:** local **admin** AWS credentials for the target account; the three GitHub
  Environments (`dev`, `staging`, `prod`) created in **this** repo and in **each service** repo,
  with protection rules / required reviewers on `staging` and `prod`.
- **Run it:**

  ```sh
  task tf:bootstrap GITHUB_REPOSITORY=<owner/this-repo>          # PLATFORM_NAME=<name> to re-skin
  ```

- **Wire the one secret** into each GitHub Environment, from the outputs:

  | `terraform output`                       | Where                                   | Setting               |
  | ---------------------------------------- | --------------------------------------- | --------------------- |
  | `platform_deploy_role_arns[<env>]`       | this repo, Environment `<env>`          | `AWS_DEPLOY_ROLE_ARN` |
  | `service_deploy_role_arns[<svc>][<env>]` | the service's repo, Environment `<env>` | `AWS_DEPLOY_ROLE_ARN` |
  | (optional) region override               | either repo                             | `AWS_REGION` var      |

## Register a service

1. Add `{ name = "<service_name>", github_repository = "<owner>/<repo>" }` to `services` in
   `terraform/bootstrap/variables.tf` (or pass `-var`). `name` must equal the `service_name` the API
   repo deploys with (its `terraform.tfvars`).
2. `task tf:bootstrap GITHUB_REPOSITORY=…` again — it adds only the new backends and role.
3. Set `AWS_DEPLOY_ROLE_ARN` on each GitHub Environment of the service repo from
   `service_deploy_role_arns["<service_name>"]`.
4. If the service needs a hostname, make sure `dns_enabled` is on for the env; it will create
   `<service_name>.<base_domain>` itself. If it needs the WAF, `enable_waf` must be on.
5. Every IAM role the service creates (its Lambda, its RDS Proxy) must carry the service's
   **workload permissions boundary**, or `iam:CreateRole` is denied. Its ARN is derived, so the
   API template sets it by convention:
   `arn:<partition>:iam::<account>:policy/<service_name>-<env>-workload-boundary`
   (also in the bootstrap output `workload_boundary_arns`). If a service needs an action outside
   the default allowlist (`workload_boundary_actions` in
   `terraform/modules/github-oidc/variables.tf`), extend it here and re-run the bootstrap: that is
   a platform decision, by design.

Removing a service: delete it from `services`, apply (the state bucket is `prevent_destroy`; empty
and remove it by hand once the API is destroyed).

## Deploy

- The Deploy workflow runs after the CI workflow passes on `main` (`dev`), or on manual dispatch for
  `staging`/`prod` behind GitHub Environment protection rules. It assumes the env's platform deploy
  role via OIDC, builds the pre-token trigger, runs `task tf:apply ENV=<env>` (plan to a file, apply
  that plan; the plan is kept as an artifact) and then `task interface:verify ENV=<env>`.
- **Order matters:** deploy the platform for an env before any API deploys into it; an API's plan
  fails on the missing `interface/version` parameter otherwise.
- **Locally:** with AWS credentials, `task tf:plan ENV=dev` derives the backend from
  `platform_name` in the env's `terraform.tfvars` and the account id. `allowed_account_ids` in the
  tfvars makes Terraform hard-fail against the wrong account.
- **Prod guardrails:** the platform refuses to plan `prod` without `alarm_email`, `enable_waf`,
  https callback/logout URLs, `deletion_protection = true` and with a password-auth test client
  (`terraform/platform/variables.tf` validations, covered by `task tf:test`).
- **Changing the interface:** see [docs/interface](../interface/). Breaking changes bump
  `interface_version` and must be coordinated with every API stack.

## Identity (Cognito)

- One user pool per environment; the hosted UI domain is `<platform>-<env>-<suffix>`.
- Custom claims (`custom:tenant_id`, `roles`) are added by the pre-token trigger
  (`packages/cognito-pretoken`); the `admin` group maps to the `admin` role.
- Create users with the console or `aws cognito-idp admin-create-user`, setting
  `custom:tenant_id`. The dev/staging **test client** allows `USER_PASSWORD_AUTH` for CI.
- The pool carries deletion protection wherever `deletion_protection` is set; the `schema`
  block forces replacement — do not change it on a pool with users.

## Alerting and cost

- The `alarms` module ships the SNS topic `<platform>-<env>-alarms`; every API's CloudWatch alarms
  publish to it. Set `alarm_email` (required in prod) and confirm the subscription once; subscribe
  Slack/PagerDuty endpoints to the same topic.
- `monthly_budget_usd` + `alarm_email` create a monthly cost budget for the environment.
- `task cost ENV=<env>` (Infracost) estimates the platform; the Infracost workflow comments on PRs
  when `INFRACOST_API_KEY` is set.

## Rotation and recovery

- Both CMKs rotate automatically yearly; deletion windows are 30 days (7 in ephemeral envs).
- State buckets are versioned with 90-day non-current retention and `prevent_destroy`; restore a
  state file by copying an older version back.
