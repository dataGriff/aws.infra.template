# Delivery backlog

Effort key: **S** ≈ ½ day · **M** ≈ 1–2 days · **L** ≈ 3–5 days.

---

## Epic 1 — Foundations & DX

**T1.1 Pin the toolchain** — `.mise.toml` pins node/pnpm/terraform/task/tflint/scanners;
`mise install` yields identical versions locally and in CI. **S**

**T1.2 Single command source + hooks** — every check is a `task`; lefthook runs `task check`
pre-commit and `task ci` pre-push; CI calls only `task`. **M**

**T1.3 Docs skeleton + light AGENTS.md** — `docs/` fan-out, `AGENTS.md`, `CLAUDE.md`. **S**

## Epic 2 — Bootstrap: state + OIDC trust

**T2.1 State backend module** — `modules/tf-backend`: versioned, CMK-encrypted, TLS-only bucket;
encrypted lock table; `prevent_destroy`. **M**

**T2.2 OIDC deploy-role factory** — `modules/github-oidc`: provider + roles trusting
`repo:<repo>:environment:<env>`; admin vs scoped (PowerUser + IAM prefix + own state + interface
read). **M**

**T2.3 Bootstrap root** — per env: platform backend + role, and one of each per registered
`service`; derived names; outputs the ARNs to wire into GitHub Environments. **M**

## Epic 3 — Network & encryption

**T3.1 Network** — VPC, subnets, endpoints (no NAT by default), flow logs, opt-in NAT + EIP. **L**

**T3.2 KMS** — `data` + `ops` CMKs with explicit policies (logs, alarms). **S**

## Epic 4 — Identity

**T4.1 Cognito** — pool, hosted UI, app client, dev/staging test client, guardrails. **M**

**T4.2 Pre-token trigger** — `packages/cognito-pretoken` adds `custom:tenant_id` + `roles`;
unit-tested; bundled by esbuild; wired to the pool. **S**

## Epic 5 — Edge

**T5.1 WAF** — managed rule groups + rate limit + redacted logging; mandatory in prod. **S**

**T5.2 DNS** — wildcard certificate for `*.<base_domain>` with DNS validation. **S**

**T5.3 Static ingress IPs** — Global Accelerator + internal NLB (opt-in). **M**

## Epic 6 — Alerting, budget, account settings

**T6.1 Alarm topic** — CMK-encrypted SNS topic with a policy allowing CloudWatch alarms from any
stack in the account; optional email. **S**

**T6.2 Budget + API Gateway account role** — monthly budget; the account+region CloudWatch role
managed from exactly one env. **S**

## Epic 7 — The published interface

**T7.1 ssm-interface module** — String/StringList parameters under `/<platform>/<env>/`;
validation rejects other types. **S**

**T7.2 Publish + document + test** — always/optional sets in `platform/main.tf`,
`docs/interface` table, `terraform test` assertions, `interface:verify` after deploy. **M**

## Epic 8 — CI/CD

**T8.1 CI parity + security** — `ci.yml` runs `task ci`; `security.yml` runs scanners + SBOM;
Infracost on PRs. **M**

**T8.2 Deploy (OIDC) + release** — `deploy.yml` builds, applies per env, verifies the interface;
`release.yml` tags + changelog. **M**

## Epic 9 — Docs & reuse

**T9.1 Docs fan-out** — architecture, interface, operations, security, testing, tutorial. **M**

**T9.2 register-service skill** — walks adding an API to `services` and wiring its repo. **S**
