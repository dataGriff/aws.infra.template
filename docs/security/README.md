# Security

The platform is secure-by-default and is the trust boundary every API inherits.

- **Deploy trust**: GitHub OIDC only (no long-lived keys). One role per (repository, environment),
  trust scoped to `repo:<owner>/<repo>:environment:<env>` so only that repo, from a job bound to
  that GitHub Environment (where reviewers live), can assume it. Platform roles are administrators;
  **service roles** get `PowerUserAccess` + IAM scoped to `<service>-<env>-*` roles/policies, their
  own state backend, and read-only access to `/<platform>/<env>/*` parameters — with writes anywhere
  under `/<platform>/*` **explicitly denied**, so no service can alter the published interface.
  Every IAM role a service creates (its Lambda, its RDS Proxy) must carry the service's
  **workload permissions boundary** (`<service>-<env>-workload-boundary`, an allowlist of the
  action namespaces an API workload may use, never IAM): `iam:CreateRole` / `PutRolePolicy` /
  `AttachRolePolicy` are conditioned on it and removing or editing it is denied, so a service
  cannot mint a role more powerful than itself and pass it to a Lambda. Nothing else.
- **State**: per env, per owner S3 buckets — versioned, CMK-encrypted, TLS-only, non-KMS writes
  denied, public access blocked, `prevent_destroy` — with encrypted, PITR-enabled lock tables.
- **Network**: VPC flow logs on; the default security group is stripped of all rules; private
  subnets reach AWS APIs through interface/gateway endpoints and have **no** internet route unless
  `enable_egress_static_ip` adds NAT. The interface-endpoint set is per env (`interface_endpoints`,
  `endpoint_az_count`) because PrivateLink bills per endpoint per AZ; prod may not trim either
  (validations in `terraform/platform/variables.tf`), and dev ships with none until a workload
  needs one — fewer endpoints narrows reachability, it never widens it.
- **Keys**: two CMKs per env with explicit key policies (`data` for storage/secrets/tables, `ops`
  for logs/alarm topic/Lambda env). APIs receive ARNs through the interface and get grants via IAM.
- **Identity**: Cognito with a 12-char password policy, TOTP MFA available (`mfa_configuration`),
  user-existence errors suppressed, 7-day refresh tokens, deletion protection in prod, no
  password-auth client in prod (validation). Custom claims come from a trigger, never from clients.
- **Edge**: WAF (managed Common, Known-Bad-Inputs and IP-reputation rule groups + a rate-based
  rule, logs with `authorization`/`x-api-key` redacted), mandatory in prod; wildcard certificate
  with DNS validation; TLS 1.2 domains are created by APIs.
- **Interface**: only String/StringList identifiers are published (module validation); secrets
  never go through it.
- **Supply chain / CI**: gitleaks, Trivy (vuln + IaC config), Checkov, Semgrep, CycloneDX SBOM —
  all via `task` targets so they run identically in hooks and CI. **Every scanner fails the build.**
  Accepted findings are suppressed individually with a written reason (`.checkov.yaml`,
  `.trivyignore`, `#checkov:skip`, `nosemgrep`). GitHub Actions are pinned to commit SHAs; Renovate
  only auto-merges dev tooling (7-day release age).
