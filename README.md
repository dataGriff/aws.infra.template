# aws.infra.template

A **best-practice, secure AWS platform template**: the account- and environment-wide
infrastructure that every API on the platform shares, deployed with Terraform, publishing a
**versioned SSM interface** that API stacks consume.

It is one of three templates:

| Repo                                                                        | Owns                                                                              |
| --------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| **aws.infra.template** (this)                                               | The platform, per account: state + OIDC, network, KMS, identity, edge, alerting   |
| [aws.api.template](https://github.com/dataGriff/aws.api.template)           | One API service: Lambda + REST API + its own database, deployed onto the platform |
| [aws.contract.template](https://github.com/dataGriff/aws.contract.template) | The API contract, published as a package                                          |

## What the platform owns (per environment)

| Area           | Resources                                                                                                                                                                               |
| -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Bootstrap**  | One isolated Terraform state backend + GitHub OIDC deploy role per env for the platform **and for every registered API service** (scoped)                                               |
| **Network**    | VPC, public/private subnets, interface + gateway endpoints (no NAT by default; the interface set is per env and dev ships with none), flow logs, opt-in static egress IP (NAT + EIP)    |
| **Encryption** | Two CMKs with explicit policies: `data` (databases, secrets, tables) and `ops` (logs, alarm topic, Lambda env)                                                                          |
| **Identity**   | Cognito user pool + hosted UI + app client (+ dev/staging test client), pre-token-generation trigger adding `custom:tenant_id` / `roles` claims                                         |
| **Edge**       | WAF web ACL (managed rule groups + rate limit, logging with credentials redacted), wildcard ACM certificate for `*.<base_domain>`, opt-in static ingress IPs (Global Accelerator + NLB) |
| **Ops**        | Alarm SNS topic (+ email), monthly budget, the account-wide API Gateway CloudWatch role                                                                                                 |
| **Interface**  | Every id/ARN an API needs, published at `/platform/<env>/…` in SSM Parameter Store — see [docs/interface](docs/interface/)                                                              |

Guardrails: prod refuses to plan without `alarm_email`, WAF, https callback URLs, deletion protection,
and with a password-auth test client (`terraform test`, mocked, in CI).

## Quickstart

```bash
mise install                                             # pinned tools (terraform, tflint, trivy, checkov, ...)
pnpm install                                             # the pre-token trigger + git hooks
task ci                                                  # the full gate, identical to GitHub Actions (no creds)

# once per AWS account, with admin credentials:
task tf:bootstrap GITHUB_REPOSITORY=<owner>/<this repo>  # state backends + deploy roles (platform + services)
task tf:plan ENV=dev                                     # then deploy.yml takes over via OIDC
```

Register an API service (its state backend + scoped deploy role) by adding it to `services` in
`terraform/bootstrap/variables.tf` — see the **register-service** skill and
[docs/operations](docs/operations/).

## Documentation

- 📐 **[Architecture](docs/architecture/)** — components, the three-repo picture, decisions
- 🔌 **[Interface](docs/interface/)** — the published SSM parameters (the platform's contract)
- 🛠️ **[Operations](docs/operations/)** — bootstrap, register a service, deploy, alerting
- 🔒 **[Security](docs/security/)** — trust boundary, network, keys, identity, scanning
- 🧪 **[Testing](docs/testing/)** — what `task ci` proves
- 📘 **[Tutorial](docs/tutorial/)** — build it yourself, as a ticket backlog

Agent/dev conventions live in [`AGENTS.md`](AGENTS.md).

## License

MIT — see [LICENSE](LICENSE).
