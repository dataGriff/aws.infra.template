# bootstrap

One-time-per-account Terraform that creates the deploy trust boundary and state storage for the
**platform and every API service registered on it**: per environment, an isolated state backend
(S3 bucket + KMS key + DynamoDB lock table) and a GitHub OIDC deploy role for the platform repo and
for each service repo — each role scoped to only its own env's state, service roles further scoped
to their own IAM name prefix and to reading the platform interface. Uses a local backend (it
_creates_ the remote ones).

Run it with `task tf:bootstrap GITHUB_REPOSITORY=<owner/repo>` — see the **First-time setup** and
**Register a service** runbooks in [`docs/operations`](../../docs/operations/README.md).
