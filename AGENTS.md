# AGENTS.md

Guidance for AI agents and developers. Kept intentionally light — details live in `docs/`.

## What this is

The **platform repo** of a three-repo AWS API template: the account/environment-wide
infrastructure every API shares (state backends + OIDC deploy roles, VPC, KMS, Cognito + pre-token
trigger, WAF, wildcard certificate, static IPs, alarm topic, budget, API Gateway account role),
deployed with Terraform per `dev`/`staging`/`prod`. API services (`aws.api.template`) deploy onto
it and read what they need from the **SSM interface** it publishes. Contracts live in
`aws.contract.template`.

## Golden rules

- **The SSM interface is the platform's contract.** Every value an API may consume is published
  under `/<platform_name>/<env>/…` by `terraform/platform/main.tf` and documented in
  `docs/interface/`. Adding a parameter is additive; renaming/removing one bumps
  `interface_version`. APIs never read platform state.
- **Everything runs through the Taskfile.** Git hooks and CI call only `task` targets.
- **Every scanner fails the build.** Accepted findings live in `.checkov.yaml` / `.trivyignore` /
  `#checkov:skip` / `nosemgrep` with a written reason.
- **Prod is guarded in code.** Add a `validation` to `terraform/platform/variables.tf` and a
  `terraform test` run for every new prod-only requirement.
- **Services are registered here, never self-bootstrapped.** An API gets its state backend and
  scoped deploy role from `terraform/bootstrap` (`services`).

## Common commands

| Command                         | Purpose                                                         |
| ------------------------------- | --------------------------------------------------------------- |
| `mise install`                  | Install all pinned tools                                        |
| `task check`                    | Fast gate (pre-commit)                                          |
| `task ci`                       | Full gate — identical locally and in CI (no credentials needed) |
| `task tf:test`                  | Guardrail + interface tests (mocked providers)                  |
| `task tf:bootstrap …`           | Once per account: backends + deploy roles                       |
| `task tf:plan ENV=dev`          | Plan an environment                                             |
| `task interface:verify ENV=dev` | Check the published parameters after a deploy                   |

## Where to look

- **Architecture & decisions:** `docs/architecture/`
- **The published interface:** `docs/interface/`
- **Runbooks (bootstrap, register a service, deploy):** `docs/operations/`
- **Security model:** `docs/security/`
- **Testing:** `docs/testing/`

## Add an API service to the platform

Run the `register-service` skill (see `.claude/skills/register-service/`).
