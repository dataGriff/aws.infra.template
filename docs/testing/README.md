# Testing

| Layer           | Tool                    | Proves                                                                                                                                                              | Runs       |
| --------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| **Unit**        | vitest                  | The pre-token trigger's claim logic (`packages/cognito-pretoken/test`)                                                                                              | `check`    |
| **Validate**    | terraform fmt/validate  | Every root (three envs + bootstrap) is well-formed                                                                                                                  | `ci`       |
| **Lint**        | tflint (+ AWS ruleset)  | Provider-specific mistakes (invalid instance types, deprecated arguments, …)                                                                                        | `ci`       |
| **Guardrails**  | terraform test (mocked) | prod refuses missing `alarm_email`, WAF off, localhost callbacks, no deletion protection, a test client; `dns_enabled` needs zone + domain                          | `ci`       |
| **Interface**   | terraform test (mocked) | Every always-present parameter is published under `/platform/<env>/`; optional ones only with their feature; the WAF ACL and certificate are published when enabled | `ci`       |
| **IaC scan**    | Trivy config + Checkov  | No HIGH/CRITICAL misconfiguration; Checkov policy with justified skips                                                                                              | `ci`       |
| **Deps**        | Trivy fs                | No HIGH/CRITICAL vulnerability in the trigger's lockfile                                                                                                            | `ci`       |
| **Post-deploy** | `task interface:verify` | Against the real account: the always-present parameters exist after the apply                                                                                       | deploy.yml |

No Docker and no AWS credentials are needed for `task ci`; `terraform test` mocks the providers.
`task check` is the pre-commit hook; `task ci` the pre-push hook and the GitHub Actions gate.
