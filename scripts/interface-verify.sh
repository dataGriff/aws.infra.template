#!/usr/bin/env bash
# Post-deploy check of the platform's published interface: every parameter the
# docs/interface table marks "always" must exist under /<platform_name>/<env>/.
# The list below is the contract API stacks pin (docs/interface/README.md);
# keep the two in step.
set -euo pipefail

ENV="${1:?usage: interface-verify.sh <env>}"
TFVARS="$(dirname "$0")/../terraform/envs/${ENV}/terraform.tfvars"
NAME="${PLATFORM_NAME:-$(sed -nE 's/^platform_name[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$TFVARS")}"
PREFIX="/${NAME}/${ENV}"

ALWAYS=(
  interface/version
  network/vpc_id network/vpc_cidr network/private_subnet_ids network/public_subnet_ids
  network/dynamodb_prefix_list_id network/nat_enabled
  kms/data_key_arn kms/ops_key_arn
  cognito/user_pool_id cognito/user_pool_arn cognito/issuer cognito/app_client_id cognito/hosted_ui_domain
  alarms/topic_arn
  apigw/cloudwatch_role_arn
)

published="$(aws ssm get-parameters-by-path --path "$PREFIX" --recursive --query 'Parameters[].Name' --output text | tr '\t' '\n')"
missing=0
for p in "${ALWAYS[@]}"; do
  if ! grep -qx "${PREFIX}/${p}" <<<"$published"; then
    echo "missing: ${PREFIX}/${p}"
    missing=1
  fi
done
count="$(grep -c . <<<"$published" || true)"
echo "interface:verify: ${count} parameters published under ${PREFIX}"
exit $missing
