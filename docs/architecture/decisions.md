# Decision log

Short ADRs — the "why" behind the platform's choices. Numbering continues the API template's log
(ADR-1…11 live in `aws.api.template`; the infra ones are restated here).

**ADR-6: Static IP and custom DNS are opt-in flags, default off.** Egress uses NAT + EIP; ingress
uses Global Accelerator (two static anycast IPs) in front of an internal NLB, because a REST API is
DNS-fronted and can't be given a fixed inbound IP directly. Both add cost, so they're off by
default. Both are platform-level: one stable egress IP and one ingress pair per environment,
shared by every API.

**ADR-7: Interface endpoints instead of NAT — but per-environment.** Private subnets have no
internet route by default, so AWS API calls go through interface endpoints. That is the right
default for prod, but PrivateLink bills per endpoint _per AZ_: the five default services across two
AZs cost roughly $75/month, which is more than the NAT gateway they replace and is charged whether
or not anything is attached to the VPC. So `interface_endpoints` and `endpoint_az_count` are
per-env variables — dev runs with none until a workload needs them, while validations in
`terraform/platform/variables.tf` stop prod trading either away. Trade-off: dev no longer proves
that a VPC-attached workload can reach the AWS APIs it calls; staging, which mirrors prod, does.

**ADR-8: mise + Taskfile as the single source of tooling and commands.** Git hooks and CI invoke
only `task` targets after `mise install`, guaranteeing local == CI.

**ADR-11: Deploy only what CI validated.** The Deploy workflow is triggered by a successful CI run
(not by the push itself), applies a saved plan, serialises per environment, and verifies the
published interface afterwards.

**ADR-12: Platform and API are separate repos; the platform publishes an SSM interface.** Shared
infrastructure (network, keys, identity, edge, alerting, state + OIDC) changed at a different pace
and blast radius from any one API, and a second API would have duplicated all of it. The platform
now owns it once per environment and publishes every consumable id/ARN under
`/<platform_name>/<env>/…`. APIs read parameters, never platform state: no cross-repo bucket
permissions, an explicit and versioned surface (`interface/version`), and platform refactors that
keep the parameters are invisible to APIs. Trade-off: two deploy pipelines, and optional
parameters must be gated by feature flags on both sides.

**ADR-16: Cognito is platform-level; databases are not.** One user pool per environment gives every
API the same identities, claims and hosted UI (users sign in once), so the pool and its pre-token
trigger live here. A database is a service's own state (database-per-service): each API owns its
Postgres, proxy and secret, encrypted with the platform's shared `data` key.

**ADR-17: Services are registered in the platform bootstrap.** An API repo never creates its own
state backend or deploy role: `terraform/bootstrap` takes a `services` list and creates, per
environment, a backend named with the API's `service_name` (the same derived names the API's
`task tf:plan` computes) and a deploy role trusting that repo's GitHub Environment, scoped to that
backend, to IAM names prefixed `<service>-<env>-`, and to reading the interface. One place lists
what may deploy into the account.
