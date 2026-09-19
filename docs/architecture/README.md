# Architecture

The platform is **one Terraform root per environment** that owns everything shared, and publishes
an interface. APIs are separate Terraform roots, in their own repos, that consume it.

```
aws.infra.template (this repo)                     aws.api.template (one per API)
┌──────────────────────────────────────────┐        ┌──────────────────────────────────┐
│ bootstrap: state backends + OIDC roles   │──────▶ │ deploy role + state backend      │
│ platform/<env>:                          │        │ (created HERE, used THERE)       │
│   network  kms  cognito(+pre-token)      │        │                                  │
│   waf  dns(wildcard cert)  ingress-ip    │        │ stack/<env>: lambda, REST API,   │
│   alarms  budget  apigw-account          │        │   postgres+proxy, secret, table, │
│        │                                 │        │   alarms, custom domain, WAF     │
│        ▼                                 │  SSM   │   association                    │
│   /platform/<env>/…  (ssm-interface) ────┼───────▶│   module "platform" (data reads) │
└──────────────────────────────────────────┘        └──────────────────────────────────┘
                                                              ▲
                                     aws.contract.template ───┘ (@datagriff/<api>-contract)
```

- **Bootstrap** (local state, once per account): per env, an isolated state backend (S3 + KMS +
  DynamoDB lock) and a GitHub OIDC deploy role for the platform repo **and for each registered
  service repo**. Platform roles are administrators; service roles are `PowerUserAccess` plus IAM
  scoped to `<service>-<env>-*` names, their own backend, and read of the interface.
- **Platform** (`terraform/platform`, composed per env under `terraform/envs/<env>`): network,
  two CMKs, Cognito (with the pre-token trigger built from `packages/cognito-pretoken`), optional
  WAF / wildcard certificate / static ingress IPs, the alarm topic, budget, the API Gateway
  account role, and finally the `ssm-interface` module that publishes the parameters.
- **Interface**: see [docs/interface](../interface/). Optional parameters exist only when their
  feature is on, so an API that needs the WAF ACL fails to plan against a platform without one
  instead of silently skipping.

See [decisions.md](decisions.md) for the ADRs.
